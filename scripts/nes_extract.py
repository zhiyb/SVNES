#!/usr/bin/env python3
from argparse import ArgumentParser
# import logging
# logger = logging.getLogger()

from rom_to_svhex import conv_svhex

def main():
    parser = ArgumentParser()
    parser.add_argument('in', type=str, default="rom.nes",
                        help='Input NES file')
    parser.add_argument('prg', type=str, default="prg_rom.svhex",
                        help='PRG ROM hex data')
    parser.add_argument('chr', type=str, default="chr_rom.svhex",
                        help='CHR ROM hex data')
    args = parser.parse_args()

    with open(getattr(args, "in"), "rb") as fin:
        hdr = fin.read(16)
        if hdr[0:4] != b'NES\x1a':
            raise RuntimeError("File magic mismatch")
        if hdr[7] & 0x0c == 0x08:
            raise RuntimeError("NES 2.0 ROM image")

        prg_size = 16 * 1024 * hdr[4]
        chr_size = 8 * 1024 * hdr[5]
        print(f"PRG ROM: {prg_size//1024} KiB, CHR ROM: {chr_size//1024} KiB")

        nt_mirror = hdr[6] & 0x01
        trainer_size = 512 if hdr[6] & 0x04 else 0
        print(f"Nametable {'vertically' if nt_mirror else 'horizontally'} mirrored")

        mapper = (hdr[6] >> 4) | (hdr[7] & 0xf0)
        print(f"Mapper {mapper}")

        # Trainer
        fin.read(trainer_size)

        # Extract PRG ROM
        with open(args.prg, "wb") as fprg:
            data = fin.read(prg_size)
            if args.prg.endswith(".svhex"):
                data = conv_svhex(data)
            fprg.write(data)

        # Extract CHR ROM
        with open(args.chr, "wb") as fchr:
            data = fin.read(chr_size)
            if args.chr.endswith(".svhex"):
                data = conv_svhex(data)
            fchr.write(data)

if __name__ == '__main__':
    main()
