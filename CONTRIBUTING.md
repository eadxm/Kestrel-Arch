# Contributing to Kestrel Arch

Thank you for your interest in contributing to Kestrel Arch! Whether you are fixing a bug in the installation script, improving the Rust/Slint GUI, or updating offline cache logic, your help is appreciated.

## How to Contribute

1. **Fork the Repository** and clone your fork locally.
2. **Create a Branch** for your feature or bug fix (`git checkout -b feature/amazing-feature`).
3. **Commit Your Changes** (`git commit -m 'Add some amazing feature'`).
4. **Push to the Branch** (`git push origin feature/amazing-feature`).
5. **Open a Pull Request** against the `main` branch.

## Project Structure
* `install.sh`: The core bash deployment engine handling partitioning, bootloaders, and pacstrap.
* `airootfs/gui-src/`: The Rust and Slint UI source code for the interactive installer.
* `.github/workflows/`: The automation pipelines handling ISO compilation and packaging.

Please ensure your code is well-tested and adheres to clean standards before submitting a pull request!
