"""
ingest.py : simulates the Source System dropping daily files into storage like S3 or Azure container.

Steps:
    1. Find feed files in data/members and data/redemptions
    2. Check each file name: NAME_YYYYMMDD_HHMMSSTT.ext
    3. Upload valid files to the Snowflake internal stage, in folders by feed and date

Run from the repo root:
    python -m ingest.ingest            
"""

import os
import re
import sys
from datetime import datetime
from pathlib import Path


# Each feed: its stage folder and file extension
FEEDS = {
    "MEMBERS": {"folder": "members", "extension": ".dat"},
    "REDEMPTIONS": {"folder": "redemptions", "extension": ".json"},
}

# Example: MEMBERS_20240115_02300000.dat
FILE_NAME_PATTERN = re.compile(r"^([A-Z]+)_(\d{8})_(\d{8})(\.[a-z]+)$")


# file name check

def parse_file_name(file_name):
    """Return (feed_name, file_date) or raise ValueError with the reason."""

    match = FILE_NAME_PATTERN.match(file_name)
    if match is None:
        raise ValueError(f"{file_name}: expected NAME_YYYYMMDD_HHMMSSTT.ext")

    feed_name, date_text, time_text, extension = match.groups()

    if feed_name not in FEEDS:
        raise ValueError(f"{file_name}: unknown feed {feed_name}")

    if extension != FEEDS[feed_name]["extension"]:
        raise ValueError(f"{file_name}: wrong extension for {feed_name}")

    # strptime fails on impossible dates such as month 13
    file_date = datetime.strptime(date_text, "%Y%m%d").date()

    return feed_name, file_date


# each file goes in the respective stage

def build_stage_path(feed_name, file_date):
    """Example: @RAW.LANDING_STAGE/members/2024/01/15/"""
    folder = FEEDS[feed_name]["folder"]
    date_folders = file_date.strftime("%Y/%m/%d")
    return f"@RAW.LANDING_STAGE/{folder}/{date_folders}/"


# build the upload plan

def plan_uploads(data_folder):
    """Return (uploads, skipped). Each upload is (local_path, stage_path)."""
    uploads = []
    skipped = []

    for feed in FEEDS.values():
        feed_folder = Path(data_folder) / feed["folder"]

        for local_path in sorted(feed_folder.rglob("*.*")):
            try:
                feed_name, file_date = parse_file_name(local_path.name)
            except ValueError as error:
                skipped.append((local_path, str(error)))
                continue

            stage_path = build_stage_path(feed_name, file_date)
            uploads.append((local_path, stage_path))

    return uploads, skipped


# Snowflake connection (details come from .env)

def connect_to_snowflake():
    import snowflake.connector
    from dotenv import load_dotenv

    load_dotenv()

    return snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        authenticator="SNOWFLAKE_JWT",
        private_key_file=os.environ["SNOWFLAKE_PRIVATE_KEY_PATH"],
        role=os.environ["SNOWFLAKE_ROLE"],
        warehouse=os.environ["SNOWFLAKE_WAREHOUSE"],
        database=os.environ["SNOWFLAKE_DATABASE"],
    )


# Main

def main():
    dry_run = "--dry-run" in sys.argv

    uploads, skipped = plan_uploads("data")

    for local_path, reason in skipped:
        print(f"SKIPPED  {reason}")

    for local_path, stage_path in uploads:
        print(f"PLANNED  {local_path.name} -> {stage_path}")

    if dry_run or not uploads:
        return

    connection = connect_to_snowflake()
    cursor = connection.cursor()

    # Upload files (OVERWRITE = FALSE skips files already in the stage)
    for local_path, stage_path in uploads:
        local_uri = "file://" + local_path.resolve().as_posix()
        cursor.execute(f"PUT '{local_uri}' {stage_path} AUTO_COMPRESS = FALSE OVERWRITE = FALSE")
        print(f"PUT      {local_path.name}")

    cursor.close()
    connection.close()

    print("Files are in the stage. The Snowflake load Tasks will load them into RAW.")


if __name__ == "__main__":
    main()