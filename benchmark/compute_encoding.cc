#include "heavy_compute.h"
#include <cstring>
#include <iostream>

namespace heavy_compute {

const char base64_table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

void EncodingCompute::compute_base64_encode(int size) {
    std::vector<unsigned char> input(size);
    std::vector<char> output(size * 4 / 3 + 4);
    
    // Initialize input
    for (int i = 0; i < size; ++i) {
        input[i] = (i * 73) % 256;
    }
    
    // Base64 encoding
    int output_idx = 0;
    for (int i = 0; i < size; i += 3) {
        int b1 = input[i];
        int b2 = (i + 1 < size) ? input[i + 1] : 0;
        int b3 = (i + 2 < size) ? input[i + 2] : 0;
        
        int n = (b1 << 16) | (b2 << 8) | b3;
        
        output[output_idx++] = base64_table[(n >> 18) & 63];
        output[output_idx++] = base64_table[(n >> 12) & 63];
        output[output_idx++] = (i + 1 < size) ? base64_table[(n >> 6) & 63] : '=';
        output[output_idx++] = (i + 2 < size) ? base64_table[n & 63] : '=';
    }
}

void EncodingCompute::compute_deflate_compress() {
    std::vector<unsigned char> data;
    data.reserve(100000);
    
    // Generate compressible data
    for (int i = 0; i < 100000; ++i) {
        data.push_back((i / 256) % 256);
    }
    
    // Simulate compression with run-length encoding
    std::vector<unsigned char> compressed;
    int i = 0;
    while (i < data.size()) {
        unsigned char current = data[i];
        int run = 1;
        while (i + run < data.size() && data[i + run] == current && run < 255) {
            run++;
        }
        compressed.push_back(run);
        compressed.push_back(current);
        i += run;
    }
}

}  // namespace heavy_compute
