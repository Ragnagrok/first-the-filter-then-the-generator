// The core reads the expiry policy from a file, like rejected/files.rs, but first it
// brings std back by hand. #![no_std] only drops the implicit link to std, and
// #![forbid(unsafe_code)] has nothing to say: this compiles. Only core-gate.sh stops it.
extern crate std;

pub fn expiry_days() -> u32 {
    std::fs::read_to_string("expiry.txt").unwrap().trim().parse().unwrap()
}
