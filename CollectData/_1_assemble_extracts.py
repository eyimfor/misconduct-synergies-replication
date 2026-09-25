# ******************************************************************************
# Per-shard extracts -> the combined/ layout the _1_ scripts read
#
# _0_shard_one.sh writes WORK/temp/<tag>/<tag>_sNNN/{cur,curIA,prev,prevIA,exams,
# disclosures*}.csv. This joins each file across shards, in shard order, keeping the
# header row of the first shard only, and writes it under the name the _1_ scripts
# expect. For the .tar.zst archives run one shard per archive: the extractor deals
# documents to shards round-robin, so only nshard=1 keeps archive order (see the
# ORDERING note in _0_onepass_extract.py).
# ******************************************************************************

import os

# Input and output folders
WORK = os.environ.get("WORK", "../collect_work")   # scratch space
temp     = WORK + "/temp"
combined = WORK + "/combined"
os.makedirs(combined, exist_ok=True)

# tag -> (scrape year, infix the employment names carry for the missing-JSON archive)
TAGS = {"raw2020": ("2020", ""), "raw2022": ("2022", ""),
        "raw2024": ("2024", ""), "miss2024": ("2024", "missing")}
EMPLOYMENT = {"cur": "currentemploymentdata", "curIA": "currentia_employmentdata",
              "prev": "previous_employmentdata", "prevIA": "previousia_employmentdata"}


# Concatenate files, keeping only the first file's header row. A byte copy,
# so each writer's line endings (CRLF, or LF for exams) survive
def join(parts, dst):
    with open(dst, "wb") as w:
        for i, p in enumerate(parts):
            with open(p, "rb") as r:
                if i:
                    r.readline()                 # later shards repeat the header
                w.write(r.read())


# Join the employment, exam and disclosure files across the shards of each scrape
for tag, (year, infix) in TAGS.items():
    shards = sorted(os.path.join(temp, tag, d) for d in os.listdir(os.path.join(temp, tag)))
    for key, base in EMPLOYMENT.items():
        join([f"{s}/{key}.csv" for s in shards], f"{combined}/{base}{infix}{year}.csv")
    join([f"{s}/exams.csv" for s in shards], f"{combined}/exams_{tag}.csv")
    ddir = f"{combined}/disclosures_{tag}"
    os.makedirs(ddir, exist_ok=True)
    for name in sorted(f for f in os.listdir(shards[0]) if f.startswith("disclosures")):
        join([f"{s}/{name}" for s in shards], f"{ddir}/{name}")
    print(f"assembled {tag}: {len(shards)} shard(s)")

# The per-scrape employment extracts are also read directly by the Table A.7 scripts
# in CreateTables/BrokerRegistrationRobustness, from $PKG/SecIAPD/output.
PKG = os.environ.get("PKG", "")
if PKG:
    dst = PKG + "/SecIAPD/output"
    os.makedirs(dst, exist_ok=True)
    for f in sorted(os.listdir(combined)):
        if f.endswith(".csv") and "employmentdata" in f:
            join([f"{combined}/{f}"], f"{dst}/{f}")
print("RUN_FINISHED=1")
