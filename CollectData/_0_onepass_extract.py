# ******************************************************************************
# Single-pass extractor: parses each adviser JSON document once and writes the
# current and previous employment extracts (broker and IA), the exam extract, and
# one disclosure file per disclosure type. These CSVs are the raw inputs to the
# employment, exam and disclosure datasets used throughout the paper.
#
# The disclosure logic is in disclosure_extractors.py: write_to_csv and the nine
# extract_* functions. Output writers stay open for the whole pass.
#
# ARCHIVE FORMATS (raw/ holds .tar.zst archives; .zip is also accepted)
#   .zip       random access. The member list is read from the central directory
#              and sliced into a contiguous run per shard.
#   .tar.zst   a stream. `zstd -dc` is piped into tarfile in streaming mode ("r|")
#              and never unpacked to disk (each archive unpacks to 9-12 GB).
#
# SHARDING DIFFERS BY FORMAT
#   A tar stream has no index, so there is no member list to slice. Every shard
#   reads the whole stream and keeps every Nth document (i % nshard == shard). The
#   shards still partition the archive, so the union across shards contains every
#   document exactly once.
#
#   ORDERING: the driver concatenates shard outputs in shard order, so contiguous
#   slicing preserves archive order while round-robin interleaves it. The rows are
#   the same; only their order differs. For output in archive order from a
#   .tar.zst, run with nshard=1.
#
# usage: _0_onepass_extract.py <archive> <outdir> <shard> <nshard>
#        <archive> is a .zip or a .tar.zst
# ******************************************************************************

import csv, json, os, re, shutil, subprocess, sys, tarfile, zipfile

# Command-line arguments and archive format
archive_path, outdir, shard, nshard = (
    sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]))

IS_TAR_ZST = archive_path.lower().endswith((".tar.zst", ".tzst"))

# .zip: the central directory gives a namelist; slice it contiguously
if not IS_TAR_ZST:
    with zipfile.ZipFile(archive_path) as z:
        names = z.namelist()
    lo = len(names) * shard // nshard
    hi = len(names) * (shard + 1) // nshard
    mine = names[lo:hi]


# Locate the zstd binary for reading .tar.zst archives
def find_zstd():
    # `zstd` is an external binary, not a pip package. Honour $ZSTD, then PATH,
    # then the usual install prefixes (conda/homebrew/system) so a replicator
    # whose shell PATH omits conda still works.
    exe = os.environ.get("ZSTD") or shutil.which("zstd")
    if exe:
        return exe
    for cand in ("/opt/homebrew/bin/zstd", "/usr/local/bin/zstd", "/usr/bin/zstd",
                 os.path.expanduser("~/anaconda3/bin/zstd"),
                 os.path.expanduser("~/opt/anaconda3/bin/zstd"),
                 os.path.expanduser("~/miniconda3/bin/zstd")):
        if os.path.isfile(cand) and os.access(cand, os.X_OK):
            return cand
    sys.exit("onepass_extract: cannot find the `zstd` binary. Install zstd "
             "(conda install zstd / brew install zstd / apt install zstd), put it "
             "on PATH, or set $ZSTD to its full path.")


# Load the disclosure extractors from this script's folder
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from disclosure_extractors import (disclosure_type_functions, write_to_csv,
                                   sanitize_filename, disclosure_headers)

# Output headers: current employment, previous employment, exams
HDR_CUR = ["individualId","CRD Number","Firm ID","Firm Name","IA Only","Registration Begin Date",
           "Firm BC Scope","Firm IA Scope","IA SEC Number","IA SEC Number Type","BD SEC Number",
           "Branch Office ID","Street","City","State","Zip Code","Country","Latitude","Longitude",
           "Non-Registered Office Flag","ELA Begin Date"]
HDR_PREV = ["individualId","Firm ID","Firm Name","IA Only","Registration Begin Date",
            "Registration End Date","Street","City","State","Zip Code","Country"]
HDR_EXAM = ["b_crd","examName","examCategory","examTakenDate","examScope",
            "state_registrations","ia_state_registrations"]

# Create the output folder and the file-handle and csv-writer dicts, keyed by extract
os.makedirs(outdir, exist_ok=True)
fh, w = {}, {}


def openw(key, path, header, lineterm="\r\n"):
    # Employment and disclosure extracts end lines with CRLF (csv.writer's excel
    # dialect); the exam extract uses LF.
    fh[key] = open(path, "w", newline="", encoding="utf-8")
    w[key] = csv.writer(fh[key], lineterminator=lineterm)
    if header:
        w[key].writerow(header)


# Open every output writer for the whole pass
openw("cur",    f"{outdir}/cur.csv",    HDR_CUR)
openw("curIA",  f"{outdir}/curIA.csv",  HDR_CUR)
openw("prev",   f"{outdir}/prev.csv",   HDR_PREV)
openw("prevIA", f"{outdir}/prevIA.csv", HDR_PREV)
openw("exams",  f"{outdir}/exams.csv",  HDR_EXAM, lineterm="\n")

# One disclosure file per type. The header row comes from disclosure_headers, so
# each per-type file is complete as written; _1_consolidate_disclosures.py reads
# it by column name
for dt in disclosure_type_functions:
    openw("d:" + dt, f"{outdir}/disclosures{sanitize_filename(dt)}.csv", disclosure_headers[dt])


# Write one current-employment row per branch office location
def emit_current(data, writer, node):
    for employment in data[node]:
        individualId = data["basicInformation"]["individualId"]
        for b in employment.get("branchOfficeLocations", []):
            writer.writerow([
                individualId or "", data.get("crdNumber", ""),
                employment.get("firmId") or "", employment.get("firmName") or "",
                employment.get("iaOnly") or "", employment.get("registrationBeginDate") or "",
                employment.get("firmBCScope") or "", employment.get("firmIAScope") or "",
                employment.get("iaSECNumber") or "", employment.get("iaSECNumberType") or "",
                employment.get("bdSECNumber") or "", b.get("branchOfficeId") or "",
                b.get("street1") or "", b.get("city") or "", b.get("state") or "",
                b.get("zipCode") or "", b.get("country") or "", b.get("latitude") or "",
                b.get("longitude") or "", b.get("nonRegisteredOfficeFlag") or "",
                b.get("elaBeginDate") or "",
            ])


# Write one previous-employment row per employment
def emit_previous(data, writer, node):
    for employment in data[node]:
        writer.writerow([
            data["basicInformation"]["individualId"] or "",
            employment.get("firmId") or "", employment.get("firmName") or "",
            employment.get("iaOnly") or "", employment.get("registrationBeginDate") or "",
            employment.get("registrationEndDate") or "", employment.get("street1") or "",
            employment.get("city") or "", employment.get("state") or "",
            employment.get("zipCode") or "", employment.get("country") or "",
        ])


# Write one exam row per exam, with the adviser's approved registration counts
def emit_exams(broker, writer, filename):
    b_crd = broker.get("basicInformation", {}).get(
        "individualId", re.findall(r"\d+", filename)[0])
    reg = broker.get("registrationCount", {})
    for category in ["stateExamCategory", "principalExamCategory", "productExamCategory"]:
        for exam in broker.get(category, []):
            writer.writerow([
                b_crd, exam.get("examName", ""), exam.get("examCategory", ""),
                exam.get("examTakenDate", ""), exam.get("examScope", ""),
                reg.get("approvedStateRegistrationCount", "0"),
                reg.get("approvedIAStateRegistrationCount", "0"),
            ])


# Write every extract for one document. Each block is guarded separately, so a
# failure in one cannot suppress the others
def emit_all(filename, data):
    for node, key, fn in (("currentEmployments", "cur", emit_current),
                          ("currentIAEmployments", "curIA", emit_current),
                          ("previousEmployments", "prev", emit_previous),
                          ("previousIAEmployments", "prevIA", emit_previous)):
        if node in data:
            try:
                fn(data, w[key], node)
            except Exception:
                pass
    try:
        emit_exams(data, w["exams"], filename)
    except Exception:
        pass
    if data:
        for dt, extract_function in disclosure_type_functions.items():
            try:
                write_to_csv(data, w["d:" + dt], dt, extract_function)
            except Exception:
                pass


# Scrapes are sometimes the raw adviser document and sometimes an
# elasticsearch envelope around it; return the adviser document
def unwrap(data):
    if "hits" in data:
        try:
            return json.loads(data["hits"]["hits"][0]["_source"]["content"])
        except KeyError:
            return json.loads(data["hits"]["hits"][0]["_source"]["iacontent"])
    return data


# ---- Extraction pass ----

# Count of documents parsed by this shard
n_docs = 0

# .zip: parse this shard's slice of the member list
if not IS_TAR_ZST:
    with zipfile.ZipFile(archive_path, "r") as z:
        for filename in mine:
            if not filename.endswith(".txt"):
                continue
            try:
                with z.open(filename) as json_file:
                    data = json.load(json_file)
                data = unwrap(data)
            except Exception:
                continue
            n_docs += 1
            emit_all(filename, data)
else:
    # .tar.zst: one sequential pass over the decompressed stream; nothing lands on
    # disk. `zstd -dc` writes the tar to stdout, tarfile reads it in "r|" stream
    # mode (no seeking), and each member is parsed as it goes by. i counts
    # candidate .txt members in stream order; this shard keeps those with
    # i % nshard == shard (see the SHARDING DIFFERS BY FORMAT note at the top)
    proc = subprocess.Popen([find_zstd(), "-dcq", archive_path],
                            stdout=subprocess.PIPE)
    try:
        with tarfile.open(fileobj=proc.stdout, mode="r|") as tar:
            i = -1
            for member in tar:
                if not member.isfile() or not member.name.endswith(".txt"):
                    continue
                i += 1
                if i % nshard != shard:
                    continue
                filename = member.name
                try:
                    json_file = tar.extractfile(member)
                    if json_file is None:
                        continue
                    data = json.load(json_file)
                    data = unwrap(data)
                except Exception:
                    continue
                n_docs += 1
                emit_all(filename, data)
    finally:
        # drain and reap so zstd never blocks on a full pipe or lingers
        if proc.stdout is not None:
            try:
                proc.stdout.close()
            except Exception:
                pass
        if proc.poll() is None:
            proc.terminate()
        proc.wait()

# Close the writers and report the document count
for f in fh.values():
    f.close()
sys.stderr.write(f"ONEPASS_DONE shard={shard} docs={n_docs}\n")
print(f"ONEPASS_DONE shard={shard} docs={n_docs}")
