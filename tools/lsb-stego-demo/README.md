# lsb-stego-demo

Tiny Rust toy for image steganography via LSB (least-significant-bit) encoding.

This uses uncompressed 24-bit BMP to keep the example small and recognizable. The
bit-hiding idea is the same after a PNG is decoded to pixel bytes.

## Commands

Generate a carrier image:

```bash
cargo run --manifest-path tools/lsb-stego-demo/Cargo.toml -- gen /tmp/carrier.bmp 320 180
```

Encode a message:

```bash
cargo run --manifest-path tools/lsb-stego-demo/Cargo.toml -- encode /tmp/carrier.bmp /tmp/stego.bmp "hello rust cz"
```

Decode a message:

```bash
cargo run --manifest-path tools/lsb-stego-demo/Cargo.toml -- decode /tmp/stego.bmp
```

Quick end-to-end demo:

```bash
cargo run --manifest-path tools/lsb-stego-demo/Cargo.toml -- demo
```
