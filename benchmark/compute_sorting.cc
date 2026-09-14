#include "heavy_compute.h"
#include <algorithm>
#include <random>
#include <iostream>

namespace heavy_compute {

void SortCompute::quick_sort_large() {
    std::vector<long> data;
    data.reserve(100000);
    
    std::mt19937 gen(42);
    std::uniform_int_distribution<> dis(1, 1000000);
    
    for (int i = 0; i < 100000; ++i) {
        data.push_back(dis(gen));
    }
    
    std::sort(data.begin(), data.end());
}

void SortCompute::merge_sort_large() {
    std::vector<double> data;
    data.reserve(50000);
    
    for (int i = 0; i < 50000; ++i) {
        data.push_back(std::sin(i * 0.001) * std::cos(i * 0.002));
    }
    
    std::stable_sort(data.begin(), data.end());
}

void SortCompute::heap_sort_large() {
    std::vector<int> data;
    data.reserve(75000);
    
    for (int i = 0; i < 75000; ++i) {
        data.push_back((i * 7919) % 1000000);
    }
    
    std::make_heap(data.begin(), data.end());
    std::sort_heap(data.begin(), data.end());
}

}  // namespace heavy_compute
