inline __attribute__((always_inline)) int read_csr(const int csr_num) {
    int result;
    __asm__ __volatile__("csrr %[result], %[csrnum]" : [result] "=r"(result) : [csrnum] "i"(csr_num));
    return result;
}


void main() {
    unsigned int volatile epoch = 0;
    while(1) {
        epoch += 1;
    }
}
