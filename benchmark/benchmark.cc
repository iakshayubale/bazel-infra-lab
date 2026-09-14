#include "heavy_compute.h"
#include <iostream>
#include <chrono>

int main() {
    std::cout << "================================" << std::endl;
    std::cout << "Heavy Computation Benchmark!!" << std::endl;
    std::cout << "================================" << std::endl;
    std::cout << std::endl;

    auto start = std::chrono::high_resolution_clock::now();
    
    std::cout << "Running matrix computations..." << std::endl;
    heavy_compute::MatrixCompute::compute_matrix_multiply(100);
    heavy_compute::MatrixCompute::compute_matrix_inverse(100);
    heavy_compute::MatrixCompute::compute_eigenvalues(100);
    
    std::cout << "Running sorting algorithms..." << std::endl;
    heavy_compute::SortCompute::quick_sort_large();
    heavy_compute::SortCompute::merge_sort_large();
    heavy_compute::SortCompute::heap_sort_large();
    
    std::cout << "Running cryptographic operations..." << std::endl;
    heavy_compute::CryptoCompute::compute_sha256(1000);
    heavy_compute::CryptoCompute::compute_rsa_operations();
    
    std::cout << "Running encoding operations..." << std::endl;
    heavy_compute::EncodingCompute::compute_base64_encode(50000);
    heavy_compute::EncodingCompute::compute_deflate_compress();
    
    std::cout << "Running neural network computations..." << std::endl;
    heavy_compute::NeuralCompute<float>::compute_forward_pass(10, 128);
    heavy_compute::NeuralCompute<float>::compute_backward_pass(10, 128);
    heavy_compute::NeuralCompute<double>::compute_forward_pass(10, 128);
    heavy_compute::NeuralCompute<double>::compute_backward_pass(10, 128);
    
    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
    
    std::cout << std::endl;
    std::cout << "================================" << std::endl;
    std::cout << "Benchmark completed!" << std::endl;
    std::cout << "Total runtime: " << duration.count() << " ms" << std::endl;
    std::cout << "================================" << std::endl;
    
    return 0;
}
