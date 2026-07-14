#pragma once
#ifdef _WIN32
#include "safewindows.h"
#if defined(WINAPI_FAMILY) && WINAPI_FAMILY != WINAPI_FAMILY_DESKTOP_APP && _WIN32_WINNT >= 0x0A00
// Prefer the *FromApp versions when we're being built in a Windows Store App context on
// Windows >= 10. *FromApp require the application to be manifested for "codeGeneration".
#define VirtualAlloc VirtualAllocFromApp
#define VirtualProtect VirtualProtectFromApp
#endif // App family partition

inline void *allocate_pages(size_t size)
{
	return VirtualAlloc(nullptr, size, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
}

#else
#include <sys/mman.h>
inline void *allocate_pages(size_t size)
{
	void *ret = mmap(nullptr, size, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0);
	return ret == MAP_FAILED ? nullptr : ret;

}
#endif

template<typename T>
class PoolAllocate
{
	static constexpr size_t PageSize = 4096;
	static constexpr size_t ChunkSize = sizeof(T) * PageSize;
	static inline size_t index = PageSize;
	static inline T *buffer = nullptr;
	public:
	static T *allocate()
	{
		if (index == PageSize)
		{
			index = 0;
			buffer = static_cast<T*>(allocate_pages(ChunkSize));
		}
		return &buffer[index++];
	}
};


