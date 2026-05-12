# Stage 1: Build
FROM rust:latest as builder

WORKDIR /usr/src/app
COPY . .

# Build the application
# Note: In a real CI environment, we'd use cargo-chef for faster caching
RUN cargo build --release

# Stage 2: Run
FROM debian:bookworm-slim

# Install runtime dependencies (OpenSSL is usually needed for sqlx/postgres)
RUN apt-get update && apt-get install -y libssl3 ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/local/bin

# Copy the binary from the builder stage
COPY --from=builder /usr/src/app/target/release/api .

# Expose the port the app runs on
EXPOSE 8080

# Run the binary
CMD ["./api"]
