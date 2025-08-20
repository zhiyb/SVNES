#!/usr/bin/env python3
from argparse import ArgumentParser

def main():
    parser = ArgumentParser()
    parser.add_argument('in', type=str, default="rom.bin",
                        help='Input binary data')
    parser.add_argument('out', type=str, default="rom.svhex",
                        help='Output hex data')
    args = parser.parse_args()

    with open(args.out, "wb") as fout:
        with open(getattr(args, "in"), "rb") as fin:
            data = fin.read()
            for i in range(0, len(data), 8):
                fout.write((" ".join([f"{v:02x}" for v in data[i:i+8]]) + "\n").encode("ascii"))

if __name__ == '__main__':
    main()
