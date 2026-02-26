use std::env;
use std::fs;
use std::io;
use std::path::Path;

#[derive(Clone, Debug)]
struct Image {
    width: u32,
    height: u32,
    rgb: Vec<u8>,
}

fn usage() {
    eprintln!("Usage:");
    eprintln!("  lsb-stego-demo gen <out.bmp> <width> <height>");
    eprintln!("  lsb-stego-demo encode <in.bmp> <out.bmp> <message>");
    eprintln!("  lsb-stego-demo decode <in.bmp>");
    eprintln!("  lsb-stego-demo demo");
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut args = env::args();
    let _bin = args.next();

    let Some(cmd) = args.next() else {
        usage();
        return Err("missing command".into());
    };

    match cmd.as_str() {
        "gen" => {
            let out = args.next().ok_or("missing output path")?;
            let width: u32 = args.next().ok_or("missing width")?.parse()?;
            let height: u32 = args.next().ok_or("missing height")?.parse()?;
            if args.next().is_some() {
                return Err("too many arguments".into());
            }
            let img = demo_image(width, height);
            write_bmp(&out, &img)?;
            println!(
                "wrote {} ({}x{}, capacity={} bytes)",
                out,
                img.width,
                img.height,
                payload_capacity_bytes(&img)
            );
        }
        "encode" => {
            let input = args.next().ok_or("missing input path")?;
            let output = args.next().ok_or("missing output path")?;
            let message = args.next().ok_or("missing message")?;
            if args.next().is_some() {
                return Err("too many arguments".into());
            }
            let mut img = read_bmp(&input)?;
            let capacity = payload_capacity_bytes(&img);
            encode_message(&mut img, message.as_bytes())?;
            write_bmp(&output, &img)?;
            println!(
                "encoded {} bytes into {} -> {} (capacity={} bytes)",
                message.len(),
                input,
                output,
                capacity
            );
        }
        "decode" => {
            let input = args.next().ok_or("missing input path")?;
            if args.next().is_some() {
                return Err("too many arguments".into());
            }
            let img = read_bmp(&input)?;
            let bytes = decode_message(&img)?;
            match String::from_utf8(bytes.clone()) {
                Ok(s) => println!("{s}"),
                Err(_) => println!("{bytes:?}"),
            }
        }
        "demo" => {
            let carrier = demo_image(320, 180);
            let mut stego = carrier.clone();
            let msg = b"hello from rust cz meetup";
            let carrier_path = "/tmp/lsb-carrier.bmp";
            let stego_path = "/tmp/lsb-stego.bmp";
            write_bmp(carrier_path, &carrier)?;
            encode_message(&mut stego, msg)?;
            write_bmp(stego_path, &stego)?;
            let decoded = decode_message(&stego)?;
            println!("carrier: {carrier_path}");
            println!("stego:   {stego_path}");
            println!("decoded: {}", String::from_utf8_lossy(&decoded));
        }
        _ => {
            usage();
            return Err(format!("unknown command: {cmd}").into());
        }
    }

    Ok(())
}

fn payload_capacity_bytes(img: &Image) -> usize {
    // 1 bit per RGB byte, minus 4 bytes reserved for message length.
    (img.rgb.len() / 8).saturating_sub(4)
}

fn demo_image(width: u32, height: u32) -> Image {
    let mut rgb = Vec::with_capacity((width as usize) * (height as usize) * 3);
    for y in 0..height {
        for x in 0..width {
            let r = ((x * 255) / width.max(1)) as u8;
            let g = ((y * 255) / height.max(1)) as u8;
            let b = (((x ^ y) * 255) / (width.max(height).max(1))) as u8;
            rgb.extend_from_slice(&[r, g, b]);
        }
    }
    Image { width, height, rgb }
}

fn encode_message(img: &mut Image, message: &[u8]) -> Result<(), Box<dyn std::error::Error>> {
    let mut payload = Vec::with_capacity(4 + message.len());
    let len: u32 = message
        .len()
        .try_into()
        .map_err(|_| "message too long (u32 length prefix)")?;
    payload.extend_from_slice(&len.to_le_bytes());
    payload.extend_from_slice(message);

    let bits_needed = payload.len() * 8;
    if bits_needed > img.rgb.len() {
        return Err(format!(
            "message too large: need {} bits, image has {} bits of capacity",
            bits_needed,
            img.rgb.len()
        )
        .into());
    }

    for (bit_index, bit) in bytes_to_bits(&payload).enumerate() {
        put_bit(&mut img.rgb[bit_index], bit);
    }

    Ok(())
}

fn decode_message(img: &Image) -> Result<Vec<u8>, Box<dyn std::error::Error>> {
    if img.rgb.len() < 32 {
        return Err("image too small".into());
    }

    let len_bits: Vec<u8> = img.rgb.iter().take(32).map(|b| b & 1).collect();
    let len_bytes = bits_to_bytes(&len_bits)?;
    let mut len_arr = [0u8; 4];
    len_arr.copy_from_slice(&len_bytes);
    let msg_len = u32::from_le_bytes(len_arr) as usize;

    let total_bits = (4usize + msg_len) * 8;
    if total_bits > img.rgb.len() {
        return Err(format!(
            "encoded length {} exceeds image capacity",
            msg_len
        )
        .into());
    }

    let msg_bits: Vec<u8> = img
        .rgb
        .iter()
        .skip(32)
        .take(msg_len * 8)
        .map(|b| b & 1)
        .collect();
    bits_to_bytes(&msg_bits).map_err(Into::into)
}

fn put_bit(byte: &mut u8, bit: u8) {
    *byte = (*byte & !1) | (bit & 1);
}

fn bytes_to_bits(bytes: &[u8]) -> impl Iterator<Item = u8> + '_ {
    bytes.iter()
        .flat_map(|byte| (0..8).map(move |shift| (byte >> shift) & 1))
}

fn bits_to_bytes(bits: &[u8]) -> io::Result<Vec<u8>> {
    if !bits.len().is_multiple_of(8) {
        return Err(io::Error::new(
            io::ErrorKind::InvalidData,
            "bit count is not divisible by 8",
        ));
    }

    let mut out = Vec::with_capacity(bits.len() / 8);
    for chunk in bits.chunks_exact(8) {
        let mut byte = 0u8;
        for (shift, bit) in chunk.iter().enumerate() {
            byte |= (bit & 1) << shift;
        }
        out.push(byte);
    }
    Ok(out)
}

fn write_bmp(path: impl AsRef<Path>, img: &Image) -> io::Result<()> {
    let width = img.width as usize;
    let height = img.height as usize;
    let row_stride = width
        .checked_mul(3)
        .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "image too wide"))?;
    let padded_stride = (row_stride + 3) & !3;
    let pixel_bytes = padded_stride
        .checked_mul(height)
        .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "image too tall"))?;
    let file_size = 14usize
        .checked_add(40)
        .and_then(|n| n.checked_add(pixel_bytes))
        .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "file too large"))?;

    let mut out = Vec::with_capacity(file_size);

    // BITMAPFILEHEADER (14 bytes)
    out.extend_from_slice(b"BM");
    push_u32_le(
        &mut out,
        u32::try_from(file_size).map_err(|_| {
            io::Error::new(io::ErrorKind::InvalidInput, "file too large for BMP header")
        })?,
    );
    push_u16_le(&mut out, 0);
    push_u16_le(&mut out, 0);
    push_u32_le(&mut out, 54); // pixel data offset

    // BITMAPINFOHEADER (40 bytes)
    push_u32_le(&mut out, 40);
    push_i32_le(
        &mut out,
        i32::try_from(img.width)
            .map_err(|_| io::Error::new(io::ErrorKind::InvalidInput, "width too large"))?,
    );
    push_i32_le(
        &mut out,
        i32::try_from(img.height)
            .map_err(|_| io::Error::new(io::ErrorKind::InvalidInput, "height too large"))?,
    ); // positive = bottom-up
    push_u16_le(&mut out, 1); // planes
    push_u16_le(&mut out, 24); // bpp
    push_u32_le(&mut out, 0); // BI_RGB
    push_u32_le(
        &mut out,
        u32::try_from(pixel_bytes).map_err(|_| {
            io::Error::new(io::ErrorKind::InvalidInput, "pixel array too large")
        })?,
    );
    push_i32_le(&mut out, 2835); // 72 DPI
    push_i32_le(&mut out, 2835);
    push_u32_le(&mut out, 0);
    push_u32_le(&mut out, 0);

    let padding = [0u8; 3];
    for y in (0..height).rev() {
        let row = &img.rgb[y * row_stride..(y + 1) * row_stride];
        for px in row.chunks_exact(3) {
            out.push(px[2]); // B
            out.push(px[1]); // G
            out.push(px[0]); // R
        }
        let pad = padded_stride - row_stride;
        out.extend_from_slice(&padding[..pad]);
    }

    fs::write(path, out)
}

fn read_bmp(path: impl AsRef<Path>) -> Result<Image, Box<dyn std::error::Error>> {
    let bytes = fs::read(path)?;
    if bytes.len() < 54 {
        return Err("BMP too small".into());
    }
    if bytes.get(0..2) != Some(b"BM") {
        return Err("not a BMP file".into());
    }

    let data_offset = read_u32_le(&bytes, 10)? as usize;
    let dib_size = read_u32_le(&bytes, 14)?;
    if dib_size < 40 {
        return Err("unsupported BMP DIB header (need BITMAPINFOHEADER+)".into());
    }

    let width_i = read_i32_le(&bytes, 18)?;
    let height_i = read_i32_le(&bytes, 22)?;
    let planes = read_u16_le(&bytes, 26)?;
    let bpp = read_u16_le(&bytes, 28)?;
    let compression = read_u32_le(&bytes, 30)?;

    if planes != 1 {
        return Err("unsupported BMP planes".into());
    }
    if bpp != 24 {
        return Err("only 24-bit BMP is supported".into());
    }
    if compression != 0 {
        return Err("compressed BMP is not supported".into());
    }
    if width_i <= 0 || height_i == 0 {
        return Err("invalid BMP dimensions".into());
    }

    let width = width_i as usize;
    let height_abs = height_i.unsigned_abs() as usize;
    let row_stride = width.checked_mul(3).ok_or("image too wide")?;
    let padded_stride = (row_stride + 3) & !3;
    let pixel_bytes = padded_stride
        .checked_mul(height_abs)
        .ok_or("image too tall")?;
    let pixel_data = bytes
        .get(data_offset..data_offset + pixel_bytes)
        .ok_or("BMP pixel data truncated")?;

    let mut rgb = vec![0u8; row_stride.checked_mul(height_abs).ok_or("image too large")?];
    let bottom_up = height_i > 0;

    for row_idx in 0..height_abs {
        let src_row = &pixel_data[row_idx * padded_stride..row_idx * padded_stride + row_stride];
        let dst_y = if bottom_up {
            height_abs - 1 - row_idx
        } else {
            row_idx
        };
        let dst_row = &mut rgb[dst_y * row_stride..(dst_y + 1) * row_stride];

        for (src_px, dst_px) in src_row.chunks_exact(3).zip(dst_row.chunks_exact_mut(3)) {
            dst_px[0] = src_px[2]; // R
            dst_px[1] = src_px[1]; // G
            dst_px[2] = src_px[0]; // B
        }
    }

    Ok(Image {
        width: width as u32,
        height: height_abs as u32,
        rgb,
    })
}

fn push_u16_le(out: &mut Vec<u8>, value: u16) {
    out.extend_from_slice(&value.to_le_bytes());
}

fn push_u32_le(out: &mut Vec<u8>, value: u32) {
    out.extend_from_slice(&value.to_le_bytes());
}

fn push_i32_le(out: &mut Vec<u8>, value: i32) {
    out.extend_from_slice(&value.to_le_bytes());
}

fn read_u16_le(bytes: &[u8], offset: usize) -> Result<u16, Box<dyn std::error::Error>> {
    let slice = bytes
        .get(offset..offset + 2)
        .ok_or("BMP header truncated (u16)")?;
    Ok(u16::from_le_bytes([slice[0], slice[1]]))
}

fn read_u32_le(bytes: &[u8], offset: usize) -> Result<u32, Box<dyn std::error::Error>> {
    let slice = bytes
        .get(offset..offset + 4)
        .ok_or("BMP header truncated (u32)")?;
    Ok(u32::from_le_bytes([slice[0], slice[1], slice[2], slice[3]]))
}

fn read_i32_le(bytes: &[u8], offset: usize) -> Result<i32, Box<dyn std::error::Error>> {
    let slice = bytes
        .get(offset..offset + 4)
        .ok_or("BMP header truncated (i32)")?;
    Ok(i32::from_le_bytes([slice[0], slice[1], slice[2], slice[3]]))
}
