# lsb-stego-demo

Tiny Rust toy for image steganography via LSB (least-significant-bit) encoding.

This uses uncompressed 24-bit BMP to keep the example small and recognizable. The
bit-hiding idea is the same after a PNG is decoded to pixel bytes.

## Commands

Generate a carrier image:

```bash
cargo run -p lsb-stego-demo -- gen /tmp/carrier.bmp 320 180
```

Encode a message:

```bash
cargo run -p lsb-stego-demo -- encode /tmp/carrier.bmp /tmp/stego.bmp "hello rust cz"
```

Decode a message:

```bash
cargo run -p lsb-stego-demo -- decode /tmp/stego.bmp
```

Quick end-to-end demo:

```bash
cargo run -p lsb-stego-demo -- demo
```
