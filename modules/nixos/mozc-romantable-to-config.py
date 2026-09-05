#!/usr/bin/env python3
"""Convert a Mozc romantable.txt to config1.db textproto format."""
import sys


def main():
    input_path = sys.argv[1]
    output_path = sys.argv[2]

    with open(input_path, "rb") as f:
        data = f.read()

    escaped = ""
    for b in data:
        if b == 0x5C:
            escaped += "\\\\"
        elif b == 0x22:
            escaped += '\\"'
        elif b == 0x0A:
            escaped += "\\n"
        elif b == 0x09:
            escaped += "\\t"
        elif 32 <= b < 127:
            escaped += chr(b)
        else:
            escaped += "\\" + format(b, "03o")

    with open(output_path, "w") as f:
        f.write(f'custom_roman_table: "{escaped}"\n')


if __name__ == "__main__":
    main()
