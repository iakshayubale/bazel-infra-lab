#include "heavy_compute.h"
#include <iostream>

namespace heavy_compute {

// Matrix multiply implementation
void MatrixCompute::compute_matrix_multiply(int size) {
    std::vector<std::vector<double>> a(size, std::vector<double>(size));
    std::vector<std::vector<double>> b(size, std::vector<double>(size));
    std::vector<std::vector<double>> c(size, std::vector<double>(size, 0.0));
    
    // Initialize matrices
    for (int i = 0; i < size; ++i) {
        for (int j = 0; j < size; ++j) {
            a[i][j] = i + j;
            b[i][j] = i - j;
        }
    }
    
    // Matrix multiplication
    for (int i = 0; i < size; ++i) {
        for (int j = 0; j < size; ++j) {
            for (int k = 0; k < size; ++k) {
                c[i][j] += a[i][k] * b[k][j];
            }
        }
    }
}

// Matrix inverse
void MatrixCompute::compute_matrix_inverse(int size) {
    std::vector<std::vector<double>> matrix(size, std::vector<double>(size));
    
    for (int i = 0; i < size; ++i) {
        for (int j = 0; j < size; ++j) {
            matrix[i][j] = (i == j) ? 2.0 : 0.5;
        }
    }
    
    // Gaussian elimination
    for (int i = 0; i < size; ++i) {
        for (int j = i + 1; j < size; ++j) {
            double factor = matrix[j][i] / matrix[i][i];
            for (int k = i; k < size; ++k) {
                matrix[j][k] -= factor * matrix[i][k];
            }
        }
    }
}

// Eigenvalue computation
void MatrixCompute::compute_eigenvalues(int size) {
    std::vector<std::vector<double>> a(size, std::vector<double>(size));
    
    // Initialize symmetric matrix
    for (int i = 0; i < size; ++i) {
        for (int j = 0; j < size; ++j) {
            a[i][j] = std::sin(i * j) * std::cos(i + j);
        }
    }
    
    // Power iteration method for largest eigenvalue
    std::vector<double> v(size, 1.0);
    for (int iter = 0; iter < 100; ++iter) {
        std::vector<double> new_v(size, 0.0);
        for (int i = 0; i < size; ++i) {
            for (int j = 0; j < size; ++j) {
                new_v[i] += a[i][j] * v[j];
            }
        }
        double norm = 0.0;
        for (double x : new_v) norm += x * x;
        norm = std::sqrt(norm);
        for (double& x : new_v) x /= norm;
        v = new_v;
    }
}

}  // namespace heavy_compute
