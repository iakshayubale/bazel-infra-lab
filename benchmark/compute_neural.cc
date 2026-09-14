#include "heavy_compute.h"
#include <cmath>
#include <iostream>

namespace heavy_compute {

// Template instantiations for neural computations
template<typename T>
void NeuralCompute<T>::compute_forward_pass(int layers, int neurons) {
    std::vector<std::vector<T>> weights(layers * neurons, std::vector<T>(neurons));
    std::vector<T> input(neurons);
    std::vector<T> output(neurons);
    
    // Initialize
    for (int i = 0; i < neurons; ++i) {
        input[i] = static_cast<T>(i) / neurons;
    }
    
    // Forward pass through layers
    for (int layer = 0; layer < layers; ++layer) {
        std::fill(output.begin(), output.end(), T(0));
        
        for (int i = 0; i < neurons; ++i) {
            for (int j = 0; j < neurons; ++j) {
                output[i] += weights[layer * neurons + i][j] * input[j];
            }
            // ReLU activation
            if (output[i] < T(0)) output[i] = T(0);
        }
        
        input = output;
    }
}

template<typename T>
void NeuralCompute<T>::compute_backward_pass(int layers, int neurons) {
    std::vector<std::vector<T>> weights(layers * neurons, std::vector<T>(neurons));
    std::vector<std::vector<T>> gradients(layers * neurons, std::vector<T>(neurons, T(0)));
    std::vector<T> delta(neurons, T(0.1));
    
    // Backward pass
    for (int layer = layers - 1; layer >= 0; --layer) {
        std::vector<T> new_delta(neurons, T(0));
        
        for (int i = 0; i < neurons; ++i) {
            for (int j = 0; j < neurons; ++j) {
                gradients[layer * neurons + i][j] = delta[i];
                new_delta[j] += weights[layer * neurons + i][j] * delta[i];
            }
        }
        
        delta = new_delta;
    }
}

// Explicit template instantiations
template class NeuralCompute<float>;
template class NeuralCompute<double>;
template class NeuralCompute<long double>;

}  // namespace heavy_compute
