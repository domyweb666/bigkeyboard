// Windows 測試用的 MemoryMappedFile 替身：整個檔讀進記憶體
#include "MemoryMappedFile.h"
#include <cstdio>
#include <cstdlib>
#include <utility>
namespace McBopomofo {
MemoryMappedFile::MemoryMappedFile(MemoryMappedFile &&o) noexcept { *this = std::move(o); }
MemoryMappedFile &MemoryMappedFile::operator=(MemoryMappedFile &&o) noexcept {
    std::swap(fd_, o.fd_); std::swap(data_, o.data_); std::swap(length_, o.length_);
    return *this;
}
MemoryMappedFile::~MemoryMappedFile() { close(); }
bool MemoryMappedFile::open(const char *path) {
    FILE *f = std::fopen(path, "rb");
    if (!f) return false;
    std::fseek(f, 0, SEEK_END);
    length_ = std::ftell(f);
    std::fseek(f, 0, SEEK_SET);
    data_ = std::malloc(length_);
    length_ = std::fread(data_, 1, length_, f);
    std::fclose(f);
    fd_ = 1;
    return true;
}
void MemoryMappedFile::close() { std::free(data_); data_ = nullptr; fd_ = -1; length_ = 0; }
} // namespace McBopomofo
