inline __attribute__((always_inline)) int read_csr(const int csr_num) {
    int result;
    __asm__ __volatile__("csrr %[result], %[csrnum]" : [result] "=r"(result) : [csrnum] "i"(csr_num));
    return result;
}

int read_misa() {
    return read_csr(0x0);
}
int read_mvendorid() {
}

int read_xlen() {
}


enum {
    CSR_CYCLE = 0xC00,
    CSR_TIME = 0xC01,
    CSR_INSTRET = 0xC02,
    CSR_CYCLEH = 0xC80,
    CSR_TIMEH = 0xC81,
    CSR_INSTRETH = 0xC82
} csr_values;

void main() {
    unsigned int epoch = 0;

    while(1) {
        epoch++;
        // FIXME(Ryan): it do not read 0xC00-YYY constant values… something something GCC.
    }
}
