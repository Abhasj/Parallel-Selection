#include <algorithm>
#include <cassert>
#include <cstdlib>
#include <iostream>
#include <vector>

using namespace std;

__global__ void addElementsToBucket (int* in, int* s, int *count, int *b, int *size_in) {
    //extern __shared__ int countLocal[];
    int index = threadIdx.x;
    // Binary Searching to find the corresponding bucket.
    int high = *b, low = 0;
    while (high - low > 1) {
        int mid = low + (high - low) / 2;
        if (s[mid] <= in[index]) {
            low = mid;
        }
        else high = mid;
    }
    //printf("%d %d %d \n", index, low, count[low]);
    atomicAdd(&count[low], 1);
    //printf("%d %d %d \n\n", index, low, count[low]);

    //__syncthreads();
    //if (index == *size_in) {
        //for (int i = 0; i < *b; ++i) {
          //  count[i] = countLocal[i];
       // }
    //}
}

__global__ void filterElements (int* in, int* left, int* right, int* out, int *i) {
    int index = threadIdx.x;
    if (in[index] >= *left && in[index] < *right) {
        // To synchronize addition
        int old_i = atomicAdd(i, 1);
        out[old_i] = in[index];
    }
}

vector<int> getSplitterElements (vector<int> a, int b) {
    // Function to generate splitter elements from the original array.
    // log(n) splitter elements will be generated.
    vector<int> s(b + 1);
    s[0] = INT_MIN;
    s[b] = INT_MAX;
    for (int i = 1; i < b; ++i) {
        int index = rand() % a.size();
        s[i] = a[index];
        swap(a[index], a[a.size() - 1]);
        a.pop_back();
    }
    return s;
}

int main() {
    int N = 15;
    vector<int> a(N);
    srand(time(0));
    generate(begin(a), end(a), []() { return rand(); });
    for (int x : a) cout << x << " ";
    cout << endl;
    int k = rand() % (N - 1) + 1;
    cout << k << endl;
   // vector<int> b = a;
   // sort(b.begin(), b.end());
   // cout << b[k - 1] << endl;
    while (a.size() > 4) {
        int b = ceil(log2(a.size())) + 1;
        vector<int> s = getSplitterElements(a, b);
        sort(s.begin(), s.end());
        vector<int> count(b, 0); // Counting the number of elements in each bucket.
        int * d_a, * d_s, * d_count, * d_b, * d_sz;
        int x = a.size();
        cudaMalloc(&d_a, a.size() * sizeof(int));
        cudaMalloc(&d_s, s.size() * sizeof(int));
        cudaMalloc(&d_count, count.size() * sizeof(int));
        cudaMalloc(&d_b, sizeof(int));
        cudaMalloc(&d_sz, sizeof(int));
        cudaMemcpy(d_a, a.data(), a.size() * sizeof(int), cudaMemcpyHostToDevice);
        cudaMemcpy(d_s, s.data(), s.size() * sizeof(int), cudaMemcpyHostToDevice);
        cudaMemcpy(d_count, count.data(), count.size() * sizeof(int), cudaMemcpyHostToDevice);
        cudaMemcpy(d_b, &b, sizeof(int), cudaMemcpyHostToDevice);
        cudaMemcpy(d_sz, &x, sizeof(int), cudaMemcpyHostToDevice);
        addElementsToBucket << <1, a.size()>> > (d_a, d_s, d_count, d_b, d_sz);
        cudaMemcpy(count.data(), d_count, count.size() * sizeof(int), cudaMemcpyDeviceToHost);
        int choosenBucket, numElements;
        int l, r;
        // Identifying the current bucket
        for (int i = 0; i < count.size(); ++i) {
            // prefix sums
            if (i) count[i] += count[i - 1];
            if (count[i] >= k) {
                // count[i - 1] < k
                choosenBucket = i;
                if (i) k -= count[i - 1];
                numElements = count[i] - ((i != 0) ? count[i - 1] : 0);
                l = s[i];
                r = s[i + 1];
                break;
            }
        }
        int* d_elementInBucket, * d_l, * d_r, *i;
        int y = 0;
        cudaMalloc(&d_elementInBucket, numElements * sizeof(int));
        cudaMalloc(&d_l, sizeof(int));
        cudaMalloc(&d_r, sizeof(int));
        cudaMalloc(&i, sizeof(int));
        cudaMemcpy(d_l, &l, sizeof(int), cudaMemcpyHostToDevice);
        cudaMemcpy(d_r, &r, sizeof(int), cudaMemcpyHostToDevice);
        cudaMemcpy(i, &y, sizeof(int), cudaMemcpyHostToDevice);
        filterElements << <1, a.size() >> > (d_a, d_l, d_r, d_elementInBucket, i);
        a.resize(numElements, 0);
        cudaMemcpy(a.data(), d_elementInBucket, numElements * sizeof(int), cudaMemcpyDeviceToHost);
      //  break;
    }
    sort(a.begin(), a.end());
    cout << a[k - 1] << endl;
    return 0;
}