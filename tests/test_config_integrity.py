import os
import re
import pytest

def test_config_excluded_classes_integrity():
    """
    Verifies that Config.ExcludedClasses in config/shared.lua is a table
    with integer keys and boolean values. This ensures the server-side check
    can correctly identify excluded vehicle classes.
    """
    config_path = os.path.join(os.path.dirname(__file__), '..', 'config', 'shared.lua')
    assert os.path.exists(config_path), f"Config file not found at {config_path}"

    with open(config_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find the Config.ExcludedClasses block
    # This regex looks for: Config.ExcludedClasses = { ... }
    match = re.search(r'Config\.ExcludedClasses\s*=\s*\{([^}]+)\}', content, re.DOTALL)
    assert match, "Config.ExcludedClasses block not found in config/shared.lua"

    block_content = match.group(1)

    # Strip comments (lua comments start with --)
    block_content = re.sub(r'--.*', '', block_content)

    # Check each line that looks like a table entry
    lines = block_content.split('\n')
    found_entries = 0

    for line in lines:
        line = line.strip()
        if not line:
            continue

        # Match format: [integer] = boolean,
        # e.g. [8] = true,
        entry_match = re.match(r'\[(\d+)\]\s*=\s*(true|false)', line)
        if entry_match:
            class_id = int(entry_match.group(1))
            value = entry_match.group(2)

            assert isinstance(class_id, int), f"Key {class_id} must be an integer"
            assert value in ['true', 'false'], f"Value for key {class_id} must be a boolean"
            found_entries += 1

    assert found_entries > 0, "No valid excluded class entries found in Config.ExcludedClasses"

if __name__ == "__main__":
    test_config_excluded_classes_integrity()
    print("Config integrity test passed!")
