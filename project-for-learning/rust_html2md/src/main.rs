use std::fs;

fn main() {
    let url = "https://www.rust-lang.org/";
    let output = "rust_lang.md";

    println!("Fetching HTML content from {}", url);
    let body = reqwest::blocking::get(url)
        .unwrap()
        .text()
        .unwrap();
    // Why here use `unwrap()`？ Because this is a simple example code. In production code, you should handle errors properly.
    println!("Converting HTML to Markdown");
    let md = html2md::parse_html(&body); // Use `&body` to pass a string slice, not ownership. If not so， it will cause a move error：'expected `&str`, found `String`'

    fs::write(output, md.as_bytes()).unwrap();
    println!("Markdown content written to {}", output);
}
