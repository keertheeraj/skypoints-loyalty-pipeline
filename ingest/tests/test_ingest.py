"""
Tests for ingest.py file name rules and upload planning.
No Snowflake needed:  pytest ingest/tests
"""

from datetime import date

import pytest

from ingest.ingest import build_stage_path, parse_file_name, plan_uploads


def test_valid_file_name_returns_feed_and_date():
    feed_name, file_date = parse_file_name("MEMBERS_20240115_02300000.dat")

    assert feed_name == "MEMBERS"
    assert file_date == date(2024, 1, 15)


@pytest.mark.parametrize(
    "bad_file_name",
    [
        "MEMBERS_20240115.dat",             # time part missing
        "members_20240115_02300000.dat",    # name must be upper case
        "FLIGHTS_20240115_02300000.dat",    # unknown feed
        "MEMBERS_20240115_02300000.json",   # wrong extension for MEMBERS
        "MEMBERS_20241315_02300000.dat",    # month 13 does not exist
        "IND.csv",                          # reference sample, not a feed
    ],
)
def test_invalid_file_name_is_rejected(bad_file_name):
    with pytest.raises(ValueError):
        parse_file_name(bad_file_name)


def test_stage_path_has_feed_folder_and_date():
    stage_path = build_stage_path("REDEMPTIONS", date(2024, 1, 5))

    assert stage_path == "@RAW.LANDING_STAGE/redemptions/2024/01/05/"


def test_plan_uploads_keeps_valid_files_and_skips_bad_names(tmp_path):
    # Arrange: one good file in a date folder, one badly named file
    day_folder = tmp_path / "members" / "2024" / "01" / "15"
    day_folder.mkdir(parents=True)
    (day_folder / "MEMBERS_20240115_02300000.dat").write_text("|H|\n")
    (day_folder / "old_backup.dat").write_text("old\n")

    # Act
    uploads, skipped = plan_uploads(tmp_path)

    # Assert
    assert len(uploads) == 1
    local_path, stage_path = uploads[0]
    assert local_path.name == "MEMBERS_20240115_02300000.dat"
    assert stage_path == "@RAW.LANDING_STAGE/members/2024/01/15/"

    assert len(skipped) == 1
    skipped_path, reason = skipped[0]
    assert skipped_path.name == "old_backup.dat"