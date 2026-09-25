#!/usr/bin/env python3
"""Build the CRD-based frequent-acquirer table (Appendix Table A.5).

Uses only the Python standard library. Reads merger_sample.dta and
firm_adv_controls.dta (Stata release 118) and writes
2023/tables/frequent_acquirers_crd.tex.
"""

from __future__ import annotations

import struct
from collections import defaultdict
from pathlib import Path


# Input files, relative to the package root
HERE = Path(__file__).resolve().parent
REPO = HERE.parent
MERGER_FILE = REPO / "2023/data/output/merger_sample.dta"
ADV_FILE = REPO / "2023/data/output/firm_adv_controls.dta"

# Sample window and the minimum number of unique targets for a frequent acquirer
FIRST_YEAR = 2011
LAST_YEAR = 2020
FREQUENT_THRESHOLD = 3


class Stata118Reader:
    """Small reader for selected columns from Stata release-118 files."""

    NUMERIC_FORMATS = {
        65530: "b",  # byte
        65529: "h",  # int
        65528: "i",  # long
        65527: "f",  # float
        65526: "d",  # double
    }
    NUMERIC_SIZES = {65530: 1, 65529: 2, 65528: 4, 65527: 4, 65526: 8}

    def __init__(self, path: Path):
        self.path = path
        self.data = path.read_bytes()
        self.endian = "<" if b"<byteorder>LSF</byteorder>" in self.data[:256] else ">"
        release = self._body("release").decode("ascii")
        if release != "118":
            raise ValueError(f"{path} is Stata release {release}, not release 118")

        # Variable count, observation count, types and names
        self.k = struct.unpack(self.endian + "H", self._body("K"))[0]
        self.n = struct.unpack(self.endian + "Q", self._body("N"))[0]

        type_bytes = self._body("variable_types")
        self.types = [
            struct.unpack(self.endian + "H", type_bytes[2 * i : 2 * i + 2])[0]
            for i in range(self.k)
        ]

        name_bytes = self._body("varnames")
        self.names = [
            name_bytes[129 * i : 129 * (i + 1)]
            .split(b"\0", 1)[0]
            .decode("utf-8", "replace")
            for i in range(self.k)
        ]

        # Byte width and offset of each variable within a record
        self.sizes = [self._size(t) for t in self.types]
        self.offsets = []
        record_size = 0
        for size in self.sizes:
            self.offsets.append(record_size)
            record_size += size
        self.record_size = record_size

        # Locate the data section and check its size
        self.data_start = self.data.rfind(b"<data>") + len(b"<data>")
        self.data_end = self.data.find(b"</data>", self.data_start)
        expected_bytes = self.n * self.record_size
        actual_bytes = self.data_end - self.data_start
        if actual_bytes != expected_bytes:
            raise ValueError(
                f"Unexpected data size in {path}: {actual_bytes} != {expected_bytes}"
            )

    def _body(self, tag: str) -> bytes:
        start_tag = f"<{tag}>".encode()
        end_tag = f"</{tag}>".encode()
        start = self.data.index(start_tag) + len(start_tag)
        end = self.data.index(end_tag, start)
        return self.data[start:end]

    def _size(self, type_code: int) -> int:
        if 1 <= type_code <= 2045:
            return type_code
        if type_code == 32768:  # strL reference
            return 8
        return self.NUMERIC_SIZES[type_code]

    def _decode(self, record: memoryview, column_index: int):
        type_code = self.types[column_index]
        offset = self.offsets[column_index]
        raw = bytes(record[offset : offset + self.sizes[column_index]])
        if 1 <= type_code <= 2045:
            return raw.split(b"\0", 1)[0].decode("utf-8", "replace")
        if type_code == 32768:
            raise ValueError("Selected strL columns are not supported")
        return struct.unpack(self.endian + self.NUMERIC_FORMATS[type_code], raw)[0]

    def rows(self, columns: list[str]):
        indices = [self.names.index(column) for column in columns]
        view = memoryview(self.data)
        for row_number in range(self.n):
            start = self.data_start + row_number * self.record_size
            record = view[start : start + self.record_size]
            yield tuple(self._decode(record, index) for index in indices)


def latex_escape(value: str) -> str:
    # Escape LaTeX special characters
    replacements = {
        "\\": r"\textbackslash{}",
        "&": r"\&",
        "%": r"\%",
        "$": r"\$",
        "#": r"\#",
        "_": r"\_",
        "{": r"\{",
        "}": r"\}",
    }
    return "".join(replacements.get(character, character) for character in value)


def normalized_name(value: str) -> str:
    """Normalize punctuation and common legal suffixes for duplicate checks."""
    value = value.upper().replace(".", "")
    tokens = "".join(
        character if character.isalnum() else " " for character in value
    ).split()
    if tokens and tokens[0] == "THE":
        tokens = tokens[1:]
    legal_suffixes = {
        "CO",
        "COMPANY",
        "CORP",
        "CORPORATION",
        "INC",
        "INCORPORATED",
        "LLC",
        "LP",
        "LTD",
        "LIMITED",
        "PLC",
        "PLLC",
    }
    return " ".join(token for token in tokens if token not in legal_suffixes)


def frequent_tex(rows: list[dict]) -> str:
    # Tabular fragment; the paper supplies the table environment and caption.
    lines = [
        r"{\begin{tabular}{lrr}",
        r"\toprule",
        r"Canonical Acquirer Name & Acquirer CRD & \# Unique Targets \\",
        r"\midrule",
    ]
    for row in rows:
        lines.append(
            f"{latex_escape(row['canonical_acquirer_name'])} & "
            f"{row['acquirer_crd']} & {row['unique_target_crds']} \\\\"
        )
    lines.extend([r"\bottomrule", r"\end{tabular}", "}", ""])
    return "\n".join(lines)


def main() -> None:
    # Read merger events in the sample window
    merger_reader = Stata118Reader(MERGER_FILE)
    merger_rows = [
        (int(year), int(acquirer), int(target))
        for year, acquirer, target in merger_reader.rows(
            ["mergeryear", "acquirercrds", "target_crd"]
        )
        if FIRST_YEAR <= int(year) <= LAST_YEAR
    ]

    # Check the event list: non-empty, inside the window, one event per target
    if not merger_rows:
        raise AssertionError("Event list must not be empty")
    if len(merger_rows) != merger_reader.n:
        raise AssertionError("Event list contains rows outside the sample window")
    if len({row[2] for row in merger_rows}) != len(merger_rows):
        raise AssertionError("The merger list does not have one event per target CRD")

    # Count transactions using stable identifiers.
    targets_by_acquirer: dict[int, set[int]] = defaultdict(set)
    years_by_acquirer: dict[int, list[int]] = defaultdict(list)
    for year, acquirer, target in merger_rows:
        targets_by_acquirer[acquirer].add(target)
        years_by_acquirer[acquirer].append(year)

    # Keep acquirers with at least FREQUENT_THRESHOLD unique targets
    frequent_counts = {
        acquirer: len(targets)
        for acquirer, targets in targets_by_acquirer.items()
        if len(targets) >= FREQUENT_THRESHOLD
    }

    # Look up each acquirer's ADV name as of each merger year and select the name associated
    # with the CRD's latest acquisition year as its single display name.
    controls_by_crd: dict[int, list[tuple[int, int, str]]] = defaultdict(list)
    adv_reader = Stata118Reader(ADV_FILE)
    for source_order, (name, crd, fiscal_year) in enumerate(
        adv_reader.rows(["business_name", "organizationcrd", "fiscal_year"])
    ):
        crd_int = int(crd)
        if crd_int in frequent_counts:
            controls_by_crd[crd_int].append((int(fiscal_year), source_order, name))

    # Name for an acquirer as of a merger year: the latest ADV record at or before that year
    selected_name_cache: dict[tuple[int, int], str] = {}

    def selected_name(acquirer_crd: int, merger_year: int) -> str:
        key = (acquirer_crd, merger_year)
        if key not in selected_name_cache:
            eligible = [
                row for row in controls_by_crd[acquirer_crd] if row[0] <= merger_year
            ]
            if not eligible:
                raise AssertionError(
                    f"No pre-merger ADV name for CRD {acquirer_crd} in {merger_year}"
                )
            latest_year = max(row[0] for row in eligible)
            # When fiscal years tie, keep the first record in file order.
            name_row = min(
                (row for row in eligible if row[0] == latest_year),
                key=lambda row: row[1],
            )
            selected_name_cache[key] = name_row[2]
        return selected_name_cache[key]

    # One row per frequent acquirer, named as of its latest acquisition year
    frequent_rows = []
    for acquirer_crd, count in frequent_counts.items():
        event_years = sorted(set(years_by_acquirer[acquirer_crd]))
        last_year = max(event_years)
        frequent_rows.append(
            {
                "canonical_acquirer_name": selected_name(acquirer_crd, last_year),
                "acquirer_crd": acquirer_crd,
                "unique_target_crds": count,
            }
        )

    # Sort by target count (descending), then name, then CRD
    frequent_rows.sort(
        key=lambda row: (
            -row["unique_target_crds"],
            row["canonical_acquirer_name"],
            row["acquirer_crd"],
        )
    )

    # Check that CRDs, names and normalized names are unique
    if len(frequent_rows) != len({row["acquirer_crd"] for row in frequent_rows}):
        raise AssertionError("Duplicate acquirer CRDs in frequent-acquirer output")
    if len(frequent_rows) != len(
        {row["canonical_acquirer_name"] for row in frequent_rows}
    ):
        raise AssertionError("Duplicate canonical names in frequent-acquirer output")
    if len(frequent_rows) != len(
        {normalized_name(row["canonical_acquirer_name"]) for row in frequent_rows}
    ):
        raise AssertionError(
            "Duplicate normalized canonical names in frequent-acquirer output"
        )

    # Write the table and print summary counts
    (REPO / "2023/tables/frequent_acquirers_crd.tex").write_text(
        frequent_tex(frequent_rows), encoding="utf-8"
    )
    print(f"Merger events: {len(merger_rows)}")
    print(f"Unique target CRDs: {len({row[2] for row in merger_rows})}")
    print(f"Unique acquirer CRDs: {len({row[1] for row in merger_rows})}")
    print(f"Frequent acquirer CRDs: {len(frequent_rows)}")


if __name__ == "__main__":
    main()
