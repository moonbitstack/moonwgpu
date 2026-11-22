// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// The C seam under `hal/vulkan`.
//
// Every entry point here is one Vulkan step: the layer above decides what to
// do, this file only says it in Vulkan's words. Resource handles are opaque
// pointers to the records below, so no Vulkan type appears in the ABI and the
// MoonBit side needs no header.
//
// The loader is opened at run time; nothing links against libvulkan at build
// time. Where the Vulkan headers are absent the file still compiles, reports
// that there is no loader, and every other entry point returns zero.

#if defined(__has_include)
#if __has_include(<vulkan/vulkan.h>)
#define MWG_VULKAN 1
#define VK_NO_PROTOTYPES 1
#include <vulkan/vulkan.h>
#endif
#endif
#ifndef MWG_VULKAN
#define MWG_VULKAN 0
#endif

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if MWG_VULKAN

#if defined(_WIN32)
#include <windows.h>
static HMODULE g_library;
#define MWG_LOAD(name) ((void *)GetProcAddress(g_library, name))
static int open_loader(void) {
  g_library = LoadLibraryA("vulkan-1.dll");
  return g_library != NULL;
}
#else
#include <dlfcn.h>
static void *g_library;
#define MWG_LOAD(name) dlsym(g_library, name)
static int open_loader(void) {
  static const char *names[] = {"libvulkan.so.1", "libvulkan.so",
                                "libvulkan.1.dylib", "libvulkan.dylib", 0};
  for (int i = 0; names[i]; i++) {
    g_library = dlopen(names[i], RTLD_NOW | RTLD_LOCAL);
    if (g_library) return 1;
  }
  return 0;
}
#endif

static PFN_vkGetInstanceProcAddr p_get_instance_proc_addr;
static PFN_vkCreateInstance p_create_instance;
static PFN_vkEnumerateInstanceExtensionProperties p_enumerate_instance_extensions;
static PFN_vkEnumeratePhysicalDevices p_enumerate_physical_devices;
static PFN_vkGetPhysicalDeviceProperties p_get_physical_properties;
static PFN_vkGetPhysicalDeviceFeatures2 p_get_physical_features2;
static PFN_vkGetPhysicalDeviceQueueFamilyProperties p_queue_family_properties;

static char g_error[512];

static void set_error(const char *text) {
  snprintf(g_error, sizeof(g_error), "%s", text ? text : "unknown error");
}

static const char *result_name(VkResult r) {
  switch (r) {
    case VK_SUCCESS: return "success";
    case VK_NOT_READY: return "not ready";
    case VK_TIMEOUT: return "timeout";
    case VK_INCOMPLETE: return "incomplete";
    case VK_ERROR_OUT_OF_HOST_MEMORY: return "out of host memory";
    case VK_ERROR_OUT_OF_DEVICE_MEMORY: return "out of device memory";
    case VK_ERROR_INITIALIZATION_FAILED: return "initialization failed";
    case VK_ERROR_DEVICE_LOST: return "device lost";
    case VK_ERROR_MEMORY_MAP_FAILED: return "memory map failed";
    case VK_ERROR_LAYER_NOT_PRESENT: return "layer not present";
    case VK_ERROR_EXTENSION_NOT_PRESENT: return "extension not present";
    case VK_ERROR_FEATURE_NOT_PRESENT: return "feature not present";
    case VK_ERROR_INCOMPATIBLE_DRIVER: return "incompatible driver";
    case VK_ERROR_TOO_MANY_OBJECTS: return "too many objects";
    case VK_ERROR_FORMAT_NOT_SUPPORTED: return "format not supported";
    case VK_ERROR_FRAGMENTED_POOL: return "fragmented pool";
    case VK_ERROR_OUT_OF_DATE_KHR: return "out of date";
    default: return "unknown VkResult";
  }
}

static int failed(VkResult r, const char *what) {
  if (r == VK_SUCCESS) return 0;
  snprintf(g_error, sizeof(g_error), "%s: %s", what, result_name(r));
  return 1;
}

// --- records -------------------------------------------------------------
//
// Each record carries the device that made it, so a destroy needs nothing but
// its own handle.

typedef struct Instance {
  VkInstance handle;
  uint32_t device_count;
} Instance;

typedef struct Device {
  VkDevice handle;
  VkPhysicalDevice physical;
  VkQueue queue;
  uint32_t queue_family;
  VkCommandPool pool;
  VkCommandBuffer command;
  VkCommandBuffer aux;
  VkDescriptorPool descriptors;
  VkPipelineLayout current_layout;
  VkPhysicalDeviceMemoryProperties memory;
  VkPhysicalDeviceProperties properties;
  int recording;
} Device;

typedef struct Buffer {
  VkDevice device;
  VkBuffer handle;
  VkDeviceMemory memory;
  uint8_t *mapped;
  int32_t size;
} Buffer;

typedef struct Texture {
  VkDevice device;
  VkImage handle;
  VkDeviceMemory memory;
  VkFormat format;
  int32_t width, height, depth, layers, mips, samples;
  VkImageUsageFlags usage;
} Texture;

typedef struct View {
  VkDevice device;
  VkImageView handle;
} View;

typedef struct Sampler {
  VkDevice device;
  VkSampler handle;
} Sampler;

typedef struct Shader {
  VkDevice device;
  VkShaderModule handle;
} Shader;

typedef struct SetLayout {
  VkDevice device;
  VkDescriptorSetLayout handle;
} SetLayout;

typedef struct Set {
  VkDevice device;
  VkDescriptorPool pool;
  VkDescriptorSet handle;
  VkDescriptorSetLayout layout;
} Set;

typedef struct PipelineLayout {
  VkDevice device;
  VkPipelineLayout handle;
} PipelineLayout;

typedef struct Pipeline {
  VkDevice device;
  VkPipeline handle;
  VkPipelineBindPoint bind_point;
  VkPipelineLayout layout;
} Pipeline;

typedef struct Queries {
  VkDevice device;
  VkQueryPool handle;
  int32_t count;
  int32_t timestamps;
} Queries;

#define RECORD(kind) ((kind *)(uintptr_t)handle)
#define HANDLE(ptr) ((int64_t)(uintptr_t)(ptr))
#define AT(kind, value) ((kind *)(uintptr_t)(value))

// --- entry points --------------------------------------------------------
//
// Every Vulkan call beyond the loader's own five is reached through a pointer
// resolved at run time, so the library neither links against libvulkan nor
// needs it installed to build.

static VkInstance g_instance;
static VkDevice g_device;
static PFN_vkGetDeviceProcAddr p_get_device_proc_addr;

static void *resolve(const char *name) {
  void *function = 0;
  if (g_device && p_get_device_proc_addr)
    function = (void *)(uintptr_t)p_get_device_proc_addr(g_device, name);
  if (!function && g_instance && p_get_instance_proc_addr)
    function = (void *)(uintptr_t)p_get_instance_proc_addr(g_instance, name);
  return function;
}

#define LOAD(name) p_##name = (PFN_##name)resolve(#name)

static PFN_vkAllocateCommandBuffers p_vkAllocateCommandBuffers;
#define vkAllocateCommandBuffers p_vkAllocateCommandBuffers
static PFN_vkAllocateDescriptorSets p_vkAllocateDescriptorSets;
#define vkAllocateDescriptorSets p_vkAllocateDescriptorSets
static PFN_vkAllocateMemory p_vkAllocateMemory;
#define vkAllocateMemory p_vkAllocateMemory
static PFN_vkBeginCommandBuffer p_vkBeginCommandBuffer;
#define vkBeginCommandBuffer p_vkBeginCommandBuffer
static PFN_vkBindBufferMemory p_vkBindBufferMemory;
#define vkBindBufferMemory p_vkBindBufferMemory
static PFN_vkBindImageMemory p_vkBindImageMemory;
#define vkBindImageMemory p_vkBindImageMemory
static PFN_vkCmdBeginQuery p_vkCmdBeginQuery;
#define vkCmdBeginQuery p_vkCmdBeginQuery
static PFN_vkCmdBeginRendering p_vkCmdBeginRendering;
#define vkCmdBeginRendering p_vkCmdBeginRendering
static PFN_vkCmdBindDescriptorSets p_vkCmdBindDescriptorSets;
#define vkCmdBindDescriptorSets p_vkCmdBindDescriptorSets
static PFN_vkCmdBindIndexBuffer p_vkCmdBindIndexBuffer;
#define vkCmdBindIndexBuffer p_vkCmdBindIndexBuffer
static PFN_vkCmdBindPipeline p_vkCmdBindPipeline;
#define vkCmdBindPipeline p_vkCmdBindPipeline
static PFN_vkCmdBindVertexBuffers p_vkCmdBindVertexBuffers;
#define vkCmdBindVertexBuffers p_vkCmdBindVertexBuffers
static PFN_vkCmdClearColorImage p_vkCmdClearColorImage;
#define vkCmdClearColorImage p_vkCmdClearColorImage
static PFN_vkCmdClearDepthStencilImage p_vkCmdClearDepthStencilImage;
#define vkCmdClearDepthStencilImage p_vkCmdClearDepthStencilImage
static PFN_vkCmdCopyBuffer p_vkCmdCopyBuffer;
#define vkCmdCopyBuffer p_vkCmdCopyBuffer
static PFN_vkCmdCopyBufferToImage p_vkCmdCopyBufferToImage;
#define vkCmdCopyBufferToImage p_vkCmdCopyBufferToImage
static PFN_vkCmdCopyImage p_vkCmdCopyImage;
#define vkCmdCopyImage p_vkCmdCopyImage
static PFN_vkCmdCopyImageToBuffer p_vkCmdCopyImageToBuffer;
#define vkCmdCopyImageToBuffer p_vkCmdCopyImageToBuffer
static PFN_vkCmdCopyQueryPoolResults p_vkCmdCopyQueryPoolResults;
#define vkCmdCopyQueryPoolResults p_vkCmdCopyQueryPoolResults
static PFN_vkCmdDispatch p_vkCmdDispatch;
#define vkCmdDispatch p_vkCmdDispatch
static PFN_vkCmdDispatchIndirect p_vkCmdDispatchIndirect;
#define vkCmdDispatchIndirect p_vkCmdDispatchIndirect
static PFN_vkCmdDraw p_vkCmdDraw;
#define vkCmdDraw p_vkCmdDraw
static PFN_vkCmdDrawIndexed p_vkCmdDrawIndexed;
#define vkCmdDrawIndexed p_vkCmdDrawIndexed
static PFN_vkCmdDrawIndexedIndirect p_vkCmdDrawIndexedIndirect;
#define vkCmdDrawIndexedIndirect p_vkCmdDrawIndexedIndirect
static PFN_vkCmdDrawIndirect p_vkCmdDrawIndirect;
#define vkCmdDrawIndirect p_vkCmdDrawIndirect
static PFN_vkCmdEndQuery p_vkCmdEndQuery;
#define vkCmdEndQuery p_vkCmdEndQuery
static PFN_vkCmdEndRendering p_vkCmdEndRendering;
#define vkCmdEndRendering p_vkCmdEndRendering
static PFN_vkCmdFillBuffer p_vkCmdFillBuffer;
#define vkCmdFillBuffer p_vkCmdFillBuffer
static PFN_vkCmdPipelineBarrier p_vkCmdPipelineBarrier;
#define vkCmdPipelineBarrier p_vkCmdPipelineBarrier
static PFN_vkCmdPushConstants p_vkCmdPushConstants;
#define vkCmdPushConstants p_vkCmdPushConstants
static PFN_vkCmdSetBlendConstants p_vkCmdSetBlendConstants;
#define vkCmdSetBlendConstants p_vkCmdSetBlendConstants
static PFN_vkCmdSetScissor p_vkCmdSetScissor;
#define vkCmdSetScissor p_vkCmdSetScissor
static PFN_vkCmdSetStencilReference p_vkCmdSetStencilReference;
#define vkCmdSetStencilReference p_vkCmdSetStencilReference
static PFN_vkCmdSetViewport p_vkCmdSetViewport;
#define vkCmdSetViewport p_vkCmdSetViewport
static PFN_vkCmdWriteTimestamp p_vkCmdWriteTimestamp;
#define vkCmdWriteTimestamp p_vkCmdWriteTimestamp
static PFN_vkCreateBuffer p_vkCreateBuffer;
#define vkCreateBuffer p_vkCreateBuffer
static PFN_vkCreateCommandPool p_vkCreateCommandPool;
#define vkCreateCommandPool p_vkCreateCommandPool
static PFN_vkCreateComputePipelines p_vkCreateComputePipelines;
#define vkCreateComputePipelines p_vkCreateComputePipelines
static PFN_vkCreateDescriptorPool p_vkCreateDescriptorPool;
#define vkCreateDescriptorPool p_vkCreateDescriptorPool
static PFN_vkCreateDescriptorSetLayout p_vkCreateDescriptorSetLayout;
#define vkCreateDescriptorSetLayout p_vkCreateDescriptorSetLayout
static PFN_vkCreateDevice p_vkCreateDevice;
#define vkCreateDevice p_vkCreateDevice
static PFN_vkCreateGraphicsPipelines p_vkCreateGraphicsPipelines;
#define vkCreateGraphicsPipelines p_vkCreateGraphicsPipelines
static PFN_vkCreateImage p_vkCreateImage;
#define vkCreateImage p_vkCreateImage
static PFN_vkCreateImageView p_vkCreateImageView;
#define vkCreateImageView p_vkCreateImageView
static PFN_vkCreatePipelineLayout p_vkCreatePipelineLayout;
#define vkCreatePipelineLayout p_vkCreatePipelineLayout
static PFN_vkCreateQueryPool p_vkCreateQueryPool;
#define vkCreateQueryPool p_vkCreateQueryPool
static PFN_vkCreateSampler p_vkCreateSampler;
#define vkCreateSampler p_vkCreateSampler
static PFN_vkCreateShaderModule p_vkCreateShaderModule;
#define vkCreateShaderModule p_vkCreateShaderModule
static PFN_vkDestroyBuffer p_vkDestroyBuffer;
#define vkDestroyBuffer p_vkDestroyBuffer
static PFN_vkDestroyCommandPool p_vkDestroyCommandPool;
#define vkDestroyCommandPool p_vkDestroyCommandPool
static PFN_vkDestroyDescriptorPool p_vkDestroyDescriptorPool;
#define vkDestroyDescriptorPool p_vkDestroyDescriptorPool
static PFN_vkDestroyDescriptorSetLayout p_vkDestroyDescriptorSetLayout;
#define vkDestroyDescriptorSetLayout p_vkDestroyDescriptorSetLayout
static PFN_vkDestroyDevice p_vkDestroyDevice;
#define vkDestroyDevice p_vkDestroyDevice
static PFN_vkDestroyImage p_vkDestroyImage;
#define vkDestroyImage p_vkDestroyImage
static PFN_vkDestroyImageView p_vkDestroyImageView;
#define vkDestroyImageView p_vkDestroyImageView
static PFN_vkDestroyInstance p_vkDestroyInstance;
#define vkDestroyInstance p_vkDestroyInstance
static PFN_vkDestroyPipeline p_vkDestroyPipeline;
#define vkDestroyPipeline p_vkDestroyPipeline
static PFN_vkDestroyPipelineLayout p_vkDestroyPipelineLayout;
#define vkDestroyPipelineLayout p_vkDestroyPipelineLayout
static PFN_vkDestroyQueryPool p_vkDestroyQueryPool;
#define vkDestroyQueryPool p_vkDestroyQueryPool
static PFN_vkDestroySampler p_vkDestroySampler;
#define vkDestroySampler p_vkDestroySampler
static PFN_vkDestroyShaderModule p_vkDestroyShaderModule;
#define vkDestroyShaderModule p_vkDestroyShaderModule
static PFN_vkDeviceWaitIdle p_vkDeviceWaitIdle;
#define vkDeviceWaitIdle p_vkDeviceWaitIdle
static PFN_vkEndCommandBuffer p_vkEndCommandBuffer;
#define vkEndCommandBuffer p_vkEndCommandBuffer
static PFN_vkFreeDescriptorSets p_vkFreeDescriptorSets;
#define vkFreeDescriptorSets p_vkFreeDescriptorSets
static PFN_vkFreeMemory p_vkFreeMemory;
#define vkFreeMemory p_vkFreeMemory
static PFN_vkGetBufferMemoryRequirements p_vkGetBufferMemoryRequirements;
#define vkGetBufferMemoryRequirements p_vkGetBufferMemoryRequirements
static PFN_vkGetDeviceQueue p_vkGetDeviceQueue;
#define vkGetDeviceQueue p_vkGetDeviceQueue
static PFN_vkGetImageMemoryRequirements p_vkGetImageMemoryRequirements;
#define vkGetImageMemoryRequirements p_vkGetImageMemoryRequirements
static PFN_vkGetPhysicalDeviceMemoryProperties p_vkGetPhysicalDeviceMemoryProperties;
#define vkGetPhysicalDeviceMemoryProperties p_vkGetPhysicalDeviceMemoryProperties
static PFN_vkMapMemory p_vkMapMemory;
#define vkMapMemory p_vkMapMemory
static PFN_vkQueueSubmit p_vkQueueSubmit;
#define vkQueueSubmit p_vkQueueSubmit
static PFN_vkQueueWaitIdle p_vkQueueWaitIdle;
#define vkQueueWaitIdle p_vkQueueWaitIdle
static PFN_vkResetCommandBuffer p_vkResetCommandBuffer;
#define vkResetCommandBuffer p_vkResetCommandBuffer
static PFN_vkUnmapMemory p_vkUnmapMemory;
#define vkUnmapMemory p_vkUnmapMemory
static PFN_vkUpdateDescriptorSets p_vkUpdateDescriptorSets;
#define vkUpdateDescriptorSets p_vkUpdateDescriptorSets

static void load_entry_points(void) {
  LOAD(vkAllocateCommandBuffers);
  LOAD(vkAllocateDescriptorSets);
  LOAD(vkAllocateMemory);
  LOAD(vkBeginCommandBuffer);
  LOAD(vkBindBufferMemory);
  LOAD(vkBindImageMemory);
  LOAD(vkCmdBeginQuery);
  LOAD(vkCmdBeginRendering);
  LOAD(vkCmdBindDescriptorSets);
  LOAD(vkCmdBindIndexBuffer);
  LOAD(vkCmdBindPipeline);
  LOAD(vkCmdBindVertexBuffers);
  LOAD(vkCmdClearColorImage);
  LOAD(vkCmdClearDepthStencilImage);
  LOAD(vkCmdCopyBuffer);
  LOAD(vkCmdCopyBufferToImage);
  LOAD(vkCmdCopyImage);
  LOAD(vkCmdCopyImageToBuffer);
  LOAD(vkCmdCopyQueryPoolResults);
  LOAD(vkCmdDispatch);
  LOAD(vkCmdDispatchIndirect);
  LOAD(vkCmdDraw);
  LOAD(vkCmdDrawIndexed);
  LOAD(vkCmdDrawIndexedIndirect);
  LOAD(vkCmdDrawIndirect);
  LOAD(vkCmdEndQuery);
  LOAD(vkCmdEndRendering);
  LOAD(vkCmdFillBuffer);
  LOAD(vkCmdPipelineBarrier);
  LOAD(vkCmdPushConstants);
  LOAD(vkCmdSetBlendConstants);
  LOAD(vkCmdSetScissor);
  LOAD(vkCmdSetStencilReference);
  LOAD(vkCmdSetViewport);
  LOAD(vkCmdWriteTimestamp);
  LOAD(vkCreateBuffer);
  LOAD(vkCreateCommandPool);
  LOAD(vkCreateComputePipelines);
  LOAD(vkCreateDescriptorPool);
  LOAD(vkCreateDescriptorSetLayout);
  LOAD(vkCreateDevice);
  LOAD(vkCreateGraphicsPipelines);
  LOAD(vkCreateImage);
  LOAD(vkCreateImageView);
  LOAD(vkCreatePipelineLayout);
  LOAD(vkCreateQueryPool);
  LOAD(vkCreateSampler);
  LOAD(vkCreateShaderModule);
  LOAD(vkDestroyBuffer);
  LOAD(vkDestroyCommandPool);
  LOAD(vkDestroyDescriptorPool);
  LOAD(vkDestroyDescriptorSetLayout);
  LOAD(vkDestroyDevice);
  LOAD(vkDestroyImage);
  LOAD(vkDestroyImageView);
  LOAD(vkDestroyInstance);
  LOAD(vkDestroyPipeline);
  LOAD(vkDestroyPipelineLayout);
  LOAD(vkDestroyQueryPool);
  LOAD(vkDestroySampler);
  LOAD(vkDestroyShaderModule);
  LOAD(vkDeviceWaitIdle);
  LOAD(vkEndCommandBuffer);
  LOAD(vkFreeDescriptorSets);
  LOAD(vkFreeMemory);
  LOAD(vkGetBufferMemoryRequirements);
  LOAD(vkGetDeviceQueue);
  LOAD(vkGetImageMemoryRequirements);
  LOAD(vkGetPhysicalDeviceMemoryProperties);
  LOAD(vkMapMemory);
  LOAD(vkQueueSubmit);
  LOAD(vkQueueWaitIdle);
  LOAD(vkResetCommandBuffer);
  LOAD(vkUnmapMemory);
  LOAD(vkUpdateDescriptorSets);
}


// --- memory --------------------------------------------------------------

static int32_t memory_type(Device *d, uint32_t bits,
                           VkMemoryPropertyFlags want) {
  for (uint32_t i = 0; i < d->memory.memoryTypeCount; i++) {
    if ((bits & (1u << i)) &&
        (d->memory.memoryTypes[i].propertyFlags & want) == want)
      return (int32_t)i;
  }
  return -1;
}

// --- formats -------------------------------------------------------------
//
// The name is the Vulkan spelling without the prefix, so that the table below
// is read against the header rather than against a hand-copied number.

typedef struct FormatEntry {
  const char *name;
  VkFormat format;
} FormatEntry;

static const FormatEntry g_formats[] = {
  // The uncompressed formats of the core specification, by the name
  // `TextureFormat::name` prints. The compressed families are absent: every
  // one of them needs a feature this backend does not advertise, and a name
  // that is absent is refused rather than silently turned into another
  // format.
  {"r8unorm", VK_FORMAT_R8_UNORM},
  {"r8snorm", VK_FORMAT_R8_SNORM},
  {"r8uint", VK_FORMAT_R8_UINT},
  {"r8sint", VK_FORMAT_R8_SINT},
  {"r16unorm", VK_FORMAT_R16_UNORM},
  {"r16snorm", VK_FORMAT_R16_SNORM},
  {"r16uint", VK_FORMAT_R16_UINT},
  {"r16sint", VK_FORMAT_R16_SINT},
  {"r16float", VK_FORMAT_R16_SFLOAT},
  {"rg8unorm", VK_FORMAT_R8G8_UNORM},
  {"rg8snorm", VK_FORMAT_R8G8_SNORM},
  {"rg8uint", VK_FORMAT_R8G8_UINT},
  {"rg8sint", VK_FORMAT_R8G8_SINT},
  {"r32uint", VK_FORMAT_R32_UINT},
  {"r32sint", VK_FORMAT_R32_SINT},
  {"r32float", VK_FORMAT_R32_SFLOAT},
  {"rg16unorm", VK_FORMAT_R16G16_UNORM},
  {"rg16snorm", VK_FORMAT_R16G16_SNORM},
  {"rg16uint", VK_FORMAT_R16G16_UINT},
  {"rg16sint", VK_FORMAT_R16G16_SINT},
  {"rg16float", VK_FORMAT_R16G16_SFLOAT},
  {"rgba8unorm", VK_FORMAT_R8G8B8A8_UNORM},
  {"rgba8unorm-srgb", VK_FORMAT_R8G8B8A8_SRGB},
  {"rgba8snorm", VK_FORMAT_R8G8B8A8_SNORM},
  {"rgba8uint", VK_FORMAT_R8G8B8A8_UINT},
  {"rgba8sint", VK_FORMAT_R8G8B8A8_SINT},
  {"bgra8unorm", VK_FORMAT_B8G8R8A8_UNORM},
  {"bgra8unorm-srgb", VK_FORMAT_B8G8R8A8_SRGB},
  {"rgb9e5ufloat", VK_FORMAT_E5B9G9R9_UFLOAT_PACK32},
  {"rgb10a2uint", VK_FORMAT_A2B10G10R10_UINT_PACK32},
  {"rgb10a2unorm", VK_FORMAT_A2B10G10R10_UNORM_PACK32},
  {"rg11b10ufloat", VK_FORMAT_B10G11R11_UFLOAT_PACK32},
  {"rg32uint", VK_FORMAT_R32G32_UINT},
  {"rg32sint", VK_FORMAT_R32G32_SINT},
  {"rg32float", VK_FORMAT_R32G32_SFLOAT},
  {"rgba16uint", VK_FORMAT_R16G16B16A16_UINT},
  {"rgba16sint", VK_FORMAT_R16G16B16A16_SINT},
  {"rgba16float", VK_FORMAT_R16G16B16A16_SFLOAT},
  {"rgba32uint", VK_FORMAT_R32G32B32A32_UINT},
  {"rgba32sint", VK_FORMAT_R32G32B32A32_SINT},
  {"rgba32float", VK_FORMAT_R32G32B32A32_SFLOAT},
  {"stencil8", VK_FORMAT_S8_UINT},
  {"depth16unorm", VK_FORMAT_D16_UNORM},
  {"depth24plus", VK_FORMAT_D32_SFLOAT},
  {"depth24plus-stencil8", VK_FORMAT_D24_UNORM_S8_UINT},
  {"depth32float", VK_FORMAT_D32_SFLOAT},
  {"depth32float-stencil8", VK_FORMAT_D32_SFLOAT_S8_UINT},
  // The vertex formats, by `VertexFormat::name`, so one lookup serves both
  // sides of a pipeline.
  {"uint8", VK_FORMAT_R8_UINT},
  {"uint8x2", VK_FORMAT_R8G8_UINT},
  {"uint8x4", VK_FORMAT_R8G8B8A8_UINT},
  {"sint8", VK_FORMAT_R8_SINT},
  {"sint8x2", VK_FORMAT_R8G8_SINT},
  {"sint8x4", VK_FORMAT_R8G8B8A8_SINT},
  {"unorm8", VK_FORMAT_R8_UNORM},
  {"unorm8x2", VK_FORMAT_R8G8_UNORM},
  {"unorm8x4", VK_FORMAT_R8G8B8A8_UNORM},
  {"snorm8", VK_FORMAT_R8_SNORM},
  {"snorm8x2", VK_FORMAT_R8G8_SNORM},
  {"snorm8x4", VK_FORMAT_R8G8B8A8_SNORM},
  {"uint16", VK_FORMAT_R16_UINT},
  {"uint16x2", VK_FORMAT_R16G16_UINT},
  {"uint16x4", VK_FORMAT_R16G16B16A16_UINT},
  {"sint16", VK_FORMAT_R16_SINT},
  {"sint16x2", VK_FORMAT_R16G16_SINT},
  {"sint16x4", VK_FORMAT_R16G16B16A16_SINT},
  {"unorm16", VK_FORMAT_R16_UNORM},
  {"unorm16x2", VK_FORMAT_R16G16_UNORM},
  {"unorm16x4", VK_FORMAT_R16G16B16A16_UNORM},
  {"snorm16", VK_FORMAT_R16_SNORM},
  {"snorm16x2", VK_FORMAT_R16G16_SNORM},
  {"snorm16x4", VK_FORMAT_R16G16B16A16_SNORM},
  {"float16", VK_FORMAT_R16_SFLOAT},
  {"float16x2", VK_FORMAT_R16G16_SFLOAT},
  {"float16x4", VK_FORMAT_R16G16B16A16_SFLOAT},
  {"float32", VK_FORMAT_R32_SFLOAT},
  {"float32x2", VK_FORMAT_R32G32_SFLOAT},
  {"float32x3", VK_FORMAT_R32G32B32_SFLOAT},
  {"float32x4", VK_FORMAT_R32G32B32A32_SFLOAT},
  {"uint32", VK_FORMAT_R32_UINT},
  {"uint32x2", VK_FORMAT_R32G32_UINT},
  {"uint32x3", VK_FORMAT_R32G32B32_UINT},
  {"uint32x4", VK_FORMAT_R32G32B32A32_UINT},
  {"sint32", VK_FORMAT_R32_SINT},
  {"sint32x2", VK_FORMAT_R32G32_SINT},
  {"sint32x3", VK_FORMAT_R32G32B32_SINT},
  {"sint32x4", VK_FORMAT_R32G32B32A32_SINT},
  {"unorm10-10-10-2", VK_FORMAT_A2B10G10R10_UNORM_PACK32},
  {"unorm8x4-bgra", VK_FORMAT_B8G8R8A8_UNORM},
  {"snorm10-10-10-2", VK_FORMAT_A2B10G10R10_SNORM_PACK32},
};

int64_t mwg_vk_format(const uint8_t *name, int32_t length) {
  char buffer[64];
  if (length <= 0 || length >= (int32_t)sizeof(buffer)) return 0;
  memcpy(buffer, name, (size_t)length);
  buffer[length] = 0;
  for (size_t i = 0; i < sizeof(g_formats) / sizeof(g_formats[0]); i++) {
    if (strcmp(g_formats[i].name, buffer) == 0) return (int64_t)g_formats[i].format;
  }
  return 0;
}

// --- instance ------------------------------------------------------------

int64_t mwg_vk_available(void) {
  if (!g_library && !open_loader()) {
    set_error("no Vulkan loader: neither vulkan-1.dll nor libvulkan.so.1 loads");
    return 0;
  }
  if (!p_create_instance) {
    p_get_instance_proc_addr =
        (PFN_vkGetInstanceProcAddr)MWG_LOAD("vkGetInstanceProcAddr");
    if (!p_get_instance_proc_addr) {
      set_error("vkGetInstanceProcAddr is missing from the loader");
      return 0;
    }
    p_create_instance =
        (PFN_vkCreateInstance)p_get_instance_proc_addr(0, "vkCreateInstance");
    p_enumerate_instance_extensions =
        (PFN_vkEnumerateInstanceExtensionProperties)p_get_instance_proc_addr(
            0, "vkEnumerateInstanceExtensionProperties");
    if (!p_create_instance || !p_enumerate_instance_extensions) {
      set_error("the loader does not export vkCreateInstance");
      return 0;
    }
  }
  return 1;
}

int64_t mwg_vk_error_copy(uint8_t *dst, int32_t capacity) {
  size_t n = strlen(g_error);
  if (capacity <= 0) return 0;
  if ((int32_t)n > capacity - 1) n = (size_t)(capacity - 1);
  if (n > 0) memcpy(dst, g_error, n);
  dst[n] = 0;
  return (int64_t)n;
}

static VKAPI_ATTR VkBool32 VKAPI_CALL report_message(
    VkDebugUtilsMessageSeverityFlagBitsEXT severity,
    VkDebugUtilsMessageTypeFlagsEXT type,
    const VkDebugUtilsMessengerCallbackDataEXT *data, void *user) {
  (void)severity;
  (void)type;
  (void)user;
  printf("vulkan: %s\n", data->pMessage);
  fflush(stdout);
  return VK_FALSE;
}

int64_t mwg_vk_instance_create(void) {
  if (!mwg_vk_available()) return 0;
  Instance *inst = (Instance *)calloc(1, sizeof(Instance));
  if (!inst) {
    set_error("out of host memory for the instance record");
    return 0;
  }
  VkApplicationInfo app;
  memset(&app, 0, sizeof(app));
  app.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
  app.pApplicationName = "moonwgpu";
  app.applicationVersion = 1;
  app.pEngineName = "moonwgpu";
  app.engineVersion = 1;
  app.apiVersion = VK_API_VERSION_1_3;
  uint32_t available = 0;
  p_enumerate_instance_extensions(0, &available, 0);
  VkExtensionProperties *extensions = (VkExtensionProperties *)calloc(
      available ? available : 1, sizeof(VkExtensionProperties));
  if (extensions) p_enumerate_instance_extensions(0, &available, extensions);
  const char *want = "VK_KHR_portability_enumeration";
  const char *enabled[1];
  uint32_t enabled_count = 0;
  for (uint32_t i = 0; extensions && i < available; i++) {
    if (strcmp(extensions[i].extensionName, want) == 0) enabled[enabled_count++] = want;
  }
  VkInstanceCreateInfo info;
  memset(&info, 0, sizeof(info));
  info.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
  info.pApplicationInfo = &app;
  info.enabledExtensionCount = enabled_count;
  info.ppEnabledExtensionNames = enabled_count ? enabled : 0;
  info.flags = enabled_count ? VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR : 0;
  const char *layers[1] = {"VK_LAYER_KHRONOS_validation"};
  int validation = getenv("MOONWGPU_VALIDATION") != 0;
  if (validation) {
    info.enabledLayerCount = 1;
    info.ppEnabledLayerNames = layers;
    enabled[enabled_count++] = "VK_EXT_debug_utils";
    info.enabledExtensionCount = enabled_count;
  }
  VkResult r = p_create_instance(&info, 0, &inst->handle);
  free(extensions);
  if (r == VK_ERROR_INCOMPATIBLE_DRIVER) {
    // A loader that predates 1.3 refuses the version outright; 1.1 is enough
    // for every call here except dynamic rendering, which the device checks.
    app.apiVersion = VK_API_VERSION_1_1;
    r = p_create_instance(&info, 0, &inst->handle);
  }
  if (failed(r, "vkCreateInstance")) {
    free(inst);
    return 0;
  }
  g_instance = inst->handle;
  p_get_device_proc_addr =
      (PFN_vkGetDeviceProcAddr)p_get_instance_proc_addr(inst->handle,
                                                        "vkGetDeviceProcAddr");
  load_entry_points();
  p_enumerate_physical_devices =
      (PFN_vkEnumeratePhysicalDevices)p_get_instance_proc_addr(
          inst->handle, "vkEnumeratePhysicalDevices");
  p_get_physical_properties =
      (PFN_vkGetPhysicalDeviceProperties)p_get_instance_proc_addr(
          inst->handle, "vkGetPhysicalDeviceProperties");
  p_get_physical_features2 =
      (PFN_vkGetPhysicalDeviceFeatures2)p_get_instance_proc_addr(
          inst->handle, "vkGetPhysicalDeviceFeatures2");
  p_queue_family_properties =
      (PFN_vkGetPhysicalDeviceQueueFamilyProperties)p_get_instance_proc_addr(
          inst->handle, "vkGetPhysicalDeviceQueueFamilyProperties");
  if (failed(p_enumerate_physical_devices(inst->handle, &inst->device_count, 0),
             "vkEnumeratePhysicalDevices")) {
    inst->device_count = 0;
  }
  if (validation) {
    PFN_vkCreateDebugUtilsMessengerEXT create_messenger =
        (PFN_vkCreateDebugUtilsMessengerEXT)p_get_instance_proc_addr(
            inst->handle, "vkCreateDebugUtilsMessengerEXT");
    if (create_messenger) {
      VkDebugUtilsMessengerCreateInfoEXT messenger;
      memset(&messenger, 0, sizeof(messenger));
      messenger.sType = VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT;
      messenger.messageSeverity =
          VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT |
          VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT;
      messenger.messageType = VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |
                              VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT |
                              VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT;
      messenger.pfnUserCallback = report_message;
      VkDebugUtilsMessengerEXT handle = VK_NULL_HANDLE;
      create_messenger(inst->handle, &messenger, 0, &handle);
    }
  }
  return HANDLE(inst);
}

void mwg_vk_instance_destroy(int64_t handle) {
  Instance *inst = RECORD(Instance);
  if (!inst) return;
  vkDestroyInstance(inst->handle, 0);
  if (g_device == 0) g_instance = 0;
  free(inst);
}

int32_t mwg_vk_device_count(int64_t handle) {
  Instance *inst = RECORD(Instance);
  return inst ? (int32_t)inst->device_count : 0;
}

// `dst` is 512 bytes: a 256-byte name, then four 64-bit numbers (api version,
// driver version, vendor, device type).
int64_t mwg_vk_physical_info(int64_t handle, int32_t index, uint8_t *dst) {
  Instance *inst = RECORD(Instance);
  if (!inst || index < 0 || (uint32_t)index >= inst->device_count) return 0;
  VkPhysicalDevice devices[16];
  uint32_t count = inst->device_count > 16 ? 16 : inst->device_count;
  if (failed(p_enumerate_physical_devices(inst->handle, &count, devices),
             "vkEnumeratePhysicalDevices"))
    return 0;
  VkPhysicalDeviceProperties properties;
  p_get_physical_properties(devices[index], &properties);
  size_t n = strlen(properties.deviceName);
  if (n > 255) n = 255;
  memcpy(dst, properties.deviceName, n);
  dst[n] = 0;
  int64_t numbers[4];
  numbers[0] = (int64_t)properties.apiVersion;
  numbers[1] = (int64_t)properties.driverVersion;
  numbers[2] = (int64_t)properties.vendorID;
  numbers[3] = (int64_t)properties.deviceType;
  memcpy(dst + 256, numbers, sizeof(numbers));
  return (int64_t)n;
}

// --- device --------------------------------------------------------------

int64_t mwg_vk_device_create(int64_t handle, int32_t index, int64_t *report) {
  Instance *inst = RECORD(Instance);
  if (!inst || index < 0 || (uint32_t)index >= inst->device_count) {
    set_error("no such physical device");
    return 0;
  }
  VkPhysicalDevice devices[16];
  uint32_t count = inst->device_count > 16 ? 16 : inst->device_count;
  if (failed(p_enumerate_physical_devices(inst->handle, &count, devices),
             "vkEnumeratePhysicalDevices"))
    return 0;
  VkPhysicalDevice physical = devices[index];
  uint32_t families = 0;
  p_queue_family_properties(physical, &families, 0);
  VkQueueFamilyProperties *queue_properties = (VkQueueFamilyProperties *)calloc(
      families ? families : 1, sizeof(VkQueueFamilyProperties));
  if (!queue_properties) {
    set_error("out of host memory for the queue families");
    return 0;
  }
  p_queue_family_properties(physical, &families, queue_properties);
  int32_t chosen = -1;
  for (uint32_t i = 0; i < families; i++) {
    VkQueueFlags flags = queue_properties[i].queueFlags;
    if ((flags & VK_QUEUE_GRAPHICS_BIT) && (flags & VK_QUEUE_COMPUTE_BIT) &&
        queue_properties[i].queueCount > 0) {
      chosen = (int32_t)i;
      break;
    }
  }
  free(queue_properties);
  if (chosen < 0) {
    set_error("no queue family offers graphics and compute");
    return 0;
  }
  VkPhysicalDeviceVulkan13Features features13;
  memset(&features13, 0, sizeof(features13));
  features13.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_FEATURES;
  VkPhysicalDeviceFeatures2 features2;
  memset(&features2, 0, sizeof(features2));
  features2.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2;
  features2.pNext = &features13;
  if (p_get_physical_features2) p_get_physical_features2(physical, &features2);
  VkPhysicalDeviceVulkan13Features enable13;
  memset(&enable13, 0, sizeof(enable13));
  enable13.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_FEATURES;
  enable13.dynamicRendering = features13.dynamicRendering;
  VkPhysicalDeviceFeatures wanted = features2.features;
  VkPhysicalDeviceFeatures enable;
  memset(&enable, 0, sizeof(enable));
  enable.samplerAnisotropy = wanted.samplerAnisotropy;
  enable.independentBlend = wanted.independentBlend;
  enable.depthClamp = wanted.depthClamp;
  enable.imageCubeArray = wanted.imageCubeArray;
  enable.shaderStorageImageWriteWithoutFormat =
      wanted.shaderStorageImageWriteWithoutFormat;
  enable.shaderStorageImageReadWithoutFormat =
      wanted.shaderStorageImageReadWithoutFormat;
  enable.fillModeNonSolid = wanted.fillModeNonSolid;
  enable.dualSrcBlend = wanted.dualSrcBlend;
  enable.textureCompressionBC = wanted.textureCompressionBC;
  enable.textureCompressionETC2 = wanted.textureCompressionETC2;
  enable.textureCompressionASTC_LDR = wanted.textureCompressionASTC_LDR;
  const char *extensions[] = {"VK_KHR_dynamic_rendering"};
  VkDeviceCreateInfo info;
  memset(&info, 0, sizeof(info));
  info.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
  info.pNext = &enable13;
  float priority = 1.0f;
  VkDeviceQueueCreateInfo queue;
  memset(&queue, 0, sizeof(queue));
  queue.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
  queue.queueFamilyIndex = (uint32_t)chosen;
  queue.queueCount = 1;
  queue.pQueuePriorities = &priority;
  info.queueCreateInfoCount = 1;
  info.pQueueCreateInfos = &queue;
  info.pEnabledFeatures = &enable;
  if (!enable13.dynamicRendering) {
    // Without dynamic rendering there is no way to begin a pass, and a backend
    // that skipped passes would be lying about what it drew.
    set_error(
        "the device offers no dynamic rendering (Vulkan 1.3, or the 1.2 extension)");
    return 0;
  }
  VkDevice device_handle;
  VkResult r = vkCreateDevice(physical, &info, 0, &device_handle);
  if (r != VK_SUCCESS) {
    // A 1.2 device exposes dynamic rendering as an extension instead.
    info.enabledExtensionCount = 1;
    info.ppEnabledExtensionNames = extensions;
    r = vkCreateDevice(physical, &info, 0, &device_handle);
  }
  if (failed(r, "vkCreateDevice")) return 0;
  Device *d = (Device *)calloc(1, sizeof(Device));
  if (!d) {
    set_error("out of host memory for the device record");
    return 0;
  }
  g_device = device_handle;
  load_entry_points();
  d->handle = device_handle;
  d->physical = physical;
  d->queue_family = (uint32_t)chosen;
  vkGetDeviceQueue(device_handle, (uint32_t)chosen, 0, &d->queue);
  vkGetPhysicalDeviceMemoryProperties(physical, &d->memory);
  p_get_physical_properties(physical, &d->properties);
  VkCommandPoolCreateInfo pool;
  memset(&pool, 0, sizeof(pool));
  pool.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
  pool.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT |
               VK_COMMAND_POOL_CREATE_TRANSIENT_BIT;
  pool.queueFamilyIndex = d->queue_family;
  if (failed(vkCreateCommandPool(device_handle, &pool, 0, &d->pool),
             "vkCreateCommandPool")) {
    vkDestroyDevice(device_handle, 0);
    free(d);
    return 0;
  }
  VkCommandBufferAllocateInfo alloc;
  memset(&alloc, 0, sizeof(alloc));
  alloc.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
  alloc.commandPool = d->pool;
  alloc.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
  alloc.commandBufferCount = 1;
  VkCommandBuffer buffers[2];
  alloc.commandBufferCount = 2;
  if (failed(vkAllocateCommandBuffers(device_handle, &alloc, buffers),
             "vkAllocateCommandBuffers")) {
    vkDestroyCommandPool(device_handle, d->pool, 0);
    vkDestroyDevice(device_handle, 0);
    free(d);
    return 0;
  }
  d->command = buffers[0];
  d->aux = buffers[1];
  VkDescriptorPoolSize pool_sizes[7];
  memset(pool_sizes, 0, sizeof(pool_sizes));
  pool_sizes[0].type = VK_DESCRIPTOR_TYPE_SAMPLER;
  pool_sizes[1].type = VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE;
  pool_sizes[2].type = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
  pool_sizes[3].type = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
  pool_sizes[4].type = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
  pool_sizes[5].type = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC;
  pool_sizes[6].type = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER_DYNAMIC;
  for (int i = 0; i < 7; i++) pool_sizes[i].descriptorCount = 4096;
  VkDescriptorPoolCreateInfo descriptors;
  memset(&descriptors, 0, sizeof(descriptors));
  descriptors.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO;
  descriptors.flags = VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT;
  descriptors.maxSets = 1024;
  descriptors.poolSizeCount = 7;
  descriptors.pPoolSizes = pool_sizes;
  if (failed(vkCreateDescriptorPool(device_handle, &descriptors, 0,
                                    &d->descriptors),
             "vkCreateDescriptorPool")) {
    vkDestroyDevice(device_handle, 0);
    free(d);
    return 0;
  }
  report[0] = (int64_t)enable13.dynamicRendering;
  report[1] = (int64_t)enable.samplerAnisotropy;
  report[2] = (int64_t)enable.independentBlend;
  report[3] = (int64_t)enable.depthClamp;
  report[4] = (int64_t)enable.imageCubeArray;
  report[5] = (int64_t)enable.textureCompressionBC;
  report[6] = (int64_t)enable.textureCompressionETC2;
  report[7] = (int64_t)enable.textureCompressionASTC_LDR;
  report[8] = (int64_t)enable.dualSrcBlend;
  report[9] = (int64_t)d->properties.limits.maxImageDimension2D;
  report[10] = (int64_t)d->properties.limits.maxImageDimension1D;
  report[11] = (int64_t)d->properties.limits.maxImageDimension3D;
  report[12] = (int64_t)d->properties.limits.maxColorAttachments;
  report[13] = (int64_t)d->properties.limits.maxUniformBufferRange;
  report[14] = (int64_t)d->properties.limits.maxStorageBufferRange;
  report[15] = (int64_t)d->properties.limits.minUniformBufferOffsetAlignment;
  report[16] = (int64_t)d->properties.limits.minStorageBufferOffsetAlignment;
  report[17] = (int64_t)d->properties.limits.maxComputeWorkGroupInvocations;
  report[18] = (int64_t)d->properties.limits.maxComputeSharedMemorySize;
  report[19] = (int64_t)d->properties.limits.maxComputeWorkGroupCount[0];
  report[20] = (int64_t)d->properties.limits.maxComputeWorkGroupSize[0];
  report[21] = (int64_t)d->properties.limits.maxVertexInputAttributes;
  report[22] = (int64_t)d->properties.limits.maxVertexInputBindings;
  report[23] = (int64_t)d->properties.limits.maxVertexInputBindingStride;
  report[24] = (int64_t)d->properties.limits.maxFragmentOutputAttachments;
  report[25] = (int64_t)d->properties.limits.maxPerStageDescriptorSampledImages;
  report[26] = (int64_t)d->properties.limits.maxPerStageDescriptorSamplers;
  report[27] = (int64_t)d->properties.limits.maxPerStageDescriptorStorageBuffers;
  report[28] = (int64_t)d->properties.limits.maxPerStageDescriptorUniformBuffers;
  report[29] = (int64_t)d->properties.limits.maxPerStageDescriptorStorageImages;
  report[30] = (int64_t)d->properties.limits.maxBoundDescriptorSets;
  return HANDLE(d);
}

void mwg_vk_device_destroy(int64_t handle) {
  Device *d = RECORD(Device);
  if (!d) return;
  g_device = 0;
  vkDeviceWaitIdle(d->handle);
  vkDestroyDescriptorPool(d->handle, d->descriptors, 0);
  vkDestroyCommandPool(d->handle, d->pool, 0);
  vkDestroyDevice(d->handle, 0);
  free(d);
}

int64_t mwg_vk_device_wait(int64_t handle) {
  Device *d = RECORD(Device);
  if (!d) return 0;
  return failed(vkDeviceWaitIdle(d->handle), "vkDeviceWaitIdle") ? 0 : 1;
}

// --- buffers -------------------------------------------------------------

int64_t mwg_vk_buffer_create(int64_t handle, int32_t size, int32_t usage,
                             int32_t zero) {
  Device *d = RECORD(Device);
  if (!d) return 0;
  Buffer *b = (Buffer *)calloc(1, sizeof(Buffer));
  if (!b) {
    set_error("out of host memory for the buffer record");
    return 0;
  }
  VkBufferCreateInfo info;
  memset(&info, 0, sizeof(info));
  info.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
  info.size = (VkDeviceSize)(size > 0 ? size : 1);
  // `usage` carries the WebGPU bits: 16 index, 32 vertex, 64 uniform,
  // 128 storage, 256 indirect. Copy and transfer are always on, because the
  // read-back path and the staging copies both go through them.
  VkBufferUsageFlags flags = VK_BUFFER_USAGE_TRANSFER_SRC_BIT |
                             VK_BUFFER_USAGE_TRANSFER_DST_BIT;
  if (usage & 16) flags |= VK_BUFFER_USAGE_INDEX_BUFFER_BIT;
  if (usage & 32) flags |= VK_BUFFER_USAGE_VERTEX_BUFFER_BIT;
  if (usage & 64) flags |= VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT;
  if (usage & 128) flags |= VK_BUFFER_USAGE_STORAGE_BUFFER_BIT;
  if (usage & 256) flags |= VK_BUFFER_USAGE_INDIRECT_BUFFER_BIT;
  info.usage = flags;
  info.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
  if (failed(vkCreateBuffer(d->handle, &info, 0, &b->handle), "vkCreateBuffer")) {
    free(b);
    return 0;
  }
  VkMemoryRequirements needs;
  vkGetBufferMemoryRequirements(d->handle, b->handle, &needs);
  int32_t index = memory_type(
      d, needs.memoryTypeBits,
      VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT);
  if (index < 0) {
    set_error("no host visible memory type for a buffer");
    vkDestroyBuffer(d->handle, b->handle, 0);
    free(b);
    return 0;
  }
  VkMemoryAllocateInfo alloc;
  memset(&alloc, 0, sizeof(alloc));
  alloc.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
  alloc.allocationSize = needs.size;
  alloc.memoryTypeIndex = (uint32_t)index;
  if (failed(vkAllocateMemory(d->handle, &alloc, 0, &b->memory),
             "vkAllocateMemory") ||
      failed(vkBindBufferMemory(d->handle, b->handle, b->memory, 0),
             "vkBindBufferMemory")) {
    vkDestroyBuffer(d->handle, b->handle, 0);
    free(b);
    return 0;
  }
  void *mapped = 0;
  if (failed(vkMapMemory(d->handle, b->memory, 0, VK_WHOLE_SIZE, 0, &mapped),
             "vkMapMemory")) {
    vkDestroyBuffer(d->handle, b->handle, 0);
    vkFreeMemory(d->handle, b->memory, 0);
    free(b);
    return 0;
  }
  b->device = d->handle;
  b->mapped = (uint8_t *)mapped;
  b->size = size;
  if (zero) memset(b->mapped, 0, (size_t)size);
  return HANDLE(b);
}

void mwg_vk_buffer_destroy(int64_t handle) {
  Buffer *b = RECORD(Buffer);
  if (!b) return;
  vkUnmapMemory(b->device, b->memory);
  vkDestroyBuffer(b->device, b->handle, 0);
  vkFreeMemory(b->device, b->memory, 0);
  free(b);
}

int32_t mwg_vk_buffer_write(int64_t handle, int32_t offset, const uint8_t *src,
                            int32_t length) {
  Buffer *b = RECORD(Buffer);
  if (!b) return 0;
  if (offset < 0 || length < 0 || offset + length > b->size) {
    set_error("buffer write outside the allocation");
    return 0;
  }
  memcpy(b->mapped + offset, src, (size_t)length);
  return 1;
}

int32_t mwg_vk_buffer_read(int64_t handle, int32_t offset, uint8_t *dst,
                           int32_t length) {
  Buffer *b = RECORD(Buffer);
  if (!b) return 0;
  if (offset < 0 || length < 0 || offset + length > b->size) {
    set_error("buffer read outside the allocation");
    return 0;
  }
  memcpy(dst, b->mapped + offset, (size_t)length);
  return 1;
}

// --- semantic tables -----------------------------------------------------
//
// The ABI speaks WebGPU's words, not Vulkan's: a layout is `color attachment`
// rather than 0x00000004, and a stage is `a transfer` rather than a mask. The
// two tables below are the whole of the translation.

// 0 undefined, 1 colour attachment, 2 shader read, 3 transfer source,
// 4 transfer destination, 5 general, 6 depth-stencil attachment.
static VkImageLayout layout_of(int32_t value) {
  switch (value) {
    case 1: return VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
    case 2: return VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    case 3: return VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
    case 4: return VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
    case 5: return VK_IMAGE_LAYOUT_GENERAL;
    case 6: return VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL;
    default: return VK_IMAGE_LAYOUT_UNDEFINED;
  }
}

// The use a barrier waits for: 0 nothing yet, 1 transfer, 2 colour
// attachment, 3 sampled in a shader, 4 storage, 5 depth attachment, 6 host.
static VkPipelineStageFlags stages_of(int32_t use) {
  switch (use) {
    case 1: return VK_PIPELINE_STAGE_TRANSFER_BIT;
    case 2: return VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    case 3: return VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT |
                   VK_PIPELINE_STAGE_VERTEX_SHADER_BIT |
                   VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT;
    case 4: return VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT |
                   VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT;
    case 5: return VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT |
                   VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT;
    case 6: return VK_PIPELINE_STAGE_HOST_BIT;
    default: return VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT;
  }
}

static VkAccessFlags accesses_of(int32_t use) {
  switch (use) {
    case 1: return VK_ACCESS_TRANSFER_READ_BIT | VK_ACCESS_TRANSFER_WRITE_BIT;
    case 2: return VK_ACCESS_COLOR_ATTACHMENT_READ_BIT |
                   VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
    case 3: return VK_ACCESS_SHADER_READ_BIT;
    case 4: return VK_ACCESS_SHADER_READ_BIT | VK_ACCESS_SHADER_WRITE_BIT;
    case 5: return VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_READ_BIT |
                   VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT;
    case 6: return VK_ACCESS_HOST_READ_BIT | VK_ACCESS_HOST_WRITE_BIT;
    default: return 0;
  }
}

static VkFormat format_from_handle(int64_t value) {
  return (VkFormat)(int32_t)value;
}

static int has_stencil(VkFormat format) {
  return format == VK_FORMAT_D24_UNORM_S8_UINT ||
         format == VK_FORMAT_D32_SFLOAT_S8_UINT || format == VK_FORMAT_S8_UINT;
}

static int has_depth(VkFormat format) {
  return format != VK_FORMAT_S8_UINT && format != VK_FORMAT_UNDEFINED;
}

// --- textures ------------------------------------------------------------

int64_t mwg_vk_texture_create(int64_t handle, int32_t width, int32_t height,
                              int32_t depth, int32_t layers, int32_t mips,
                              int32_t samples, int32_t dimension,
                              int64_t format, int32_t usage) {
  Device *d = RECORD(Device);
  if (!d) return 0;
  Texture *t = (Texture *)calloc(1, sizeof(Texture));
  if (!t) {
    set_error("out of host memory for the texture record");
    return 0;
  }
  VkImageUsageFlags vk_usage = VK_IMAGE_USAGE_TRANSFER_SRC_BIT |
                               VK_IMAGE_USAGE_TRANSFER_DST_BIT;
  if (usage & 1) vk_usage |= VK_IMAGE_USAGE_SAMPLED_BIT;
  if (usage & 2) vk_usage |= VK_IMAGE_USAGE_STORAGE_BIT;
  if (usage & 4) vk_usage |= VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
  if (usage & 8) vk_usage |= VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT;
  VkImageCreateInfo info;
  memset(&info, 0, sizeof(info));
  info.sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
  info.imageType = dimension == 0   ? VK_IMAGE_TYPE_1D
                   : dimension == 2 ? VK_IMAGE_TYPE_3D
                                    : VK_IMAGE_TYPE_2D;
  info.format = format_from_handle(format);
  info.extent.width = (uint32_t)(width > 0 ? width : 1);
  info.extent.height = (uint32_t)(height > 0 ? height : 1);
  info.extent.depth = (uint32_t)(depth > 0 ? depth : 1);
  info.mipLevels = (uint32_t)(mips > 0 ? mips : 1);
  info.arrayLayers = (uint32_t)(layers > 0 ? layers : 1);
  info.samples = (VkSampleCountFlagBits)(samples > 0 ? samples : 1);
  info.tiling = VK_IMAGE_TILING_OPTIMAL;
  info.usage = vk_usage;
  info.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
  info.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
  if (failed(vkCreateImage(d->handle, &info, 0, &t->handle), "vkCreateImage")) {
    free(t);
    return 0;
  }
  VkMemoryRequirements needs;
  vkGetImageMemoryRequirements(d->handle, t->handle, &needs);
  int32_t index =
      memory_type(d, needs.memoryTypeBits, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
  if (index < 0) index = memory_type(d, needs.memoryTypeBits, 0);
  VkMemoryAllocateInfo alloc;
  memset(&alloc, 0, sizeof(alloc));
  alloc.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
  alloc.allocationSize = needs.size;
  if (index < 0) {
    set_error("no memory type for an image");
    vkDestroyImage(d->handle, t->handle, 0);
    free(t);
    return 0;
  }
  alloc.memoryTypeIndex = (uint32_t)index;
  if (failed(vkAllocateMemory(d->handle, &alloc, 0, &t->memory),
             "vkAllocateMemory") ||
      failed(vkBindImageMemory(d->handle, t->handle, t->memory, 0),
             "vkBindImageMemory")) {
    vkDestroyImage(d->handle, t->handle, 0);
    free(t);
    return 0;
  }
  t->device = d->handle;
  t->format = info.format;
  t->width = width;
  t->height = height;
  t->depth = depth;
  t->layers = layers;
  t->mips = mips;
  t->samples = samples;
  t->usage = vk_usage;
  return HANDLE(t);
}

void mwg_vk_texture_destroy(int64_t handle) {
  Texture *t = RECORD(Texture);
  if (!t) return;
  vkDestroyImage(t->device, t->handle, 0);
  vkFreeMemory(t->device, t->memory, 0);
  free(t);
}

// --- views ---------------------------------------------------------------

int64_t mwg_vk_view_create(int64_t handle, int64_t texture, int64_t format,
                           int32_t dimension, int32_t aspect, int32_t base_mip,
                           int32_t mip_count, int32_t base_layer,
                           int32_t layer_count) {
  Texture *t = AT(Texture, texture);
  if (!t) {
    set_error("view of a texture that does not exist");
    return 0;
  }
  (void)texture;
  (void)handle;
  View *v = (View *)calloc(1, sizeof(View));
  if (!v) {
    set_error("out of host memory for the view record");
    return 0;
  }
  VkImageViewType type;
  switch (dimension) {
    case 0: type = VK_IMAGE_VIEW_TYPE_1D; break;
    case 2: type = VK_IMAGE_VIEW_TYPE_2D_ARRAY; break;
    case 3: type = VK_IMAGE_VIEW_TYPE_CUBE; break;
    case 4: type = VK_IMAGE_VIEW_TYPE_CUBE_ARRAY; break;
    case 5: type = VK_IMAGE_VIEW_TYPE_3D; break;
    default: type = VK_IMAGE_VIEW_TYPE_2D; break;
  }
  VkImageAspectFlags mask = VK_IMAGE_ASPECT_COLOR_BIT;
  if (aspect == 1) {
    mask = VK_IMAGE_ASPECT_DEPTH_BIT;
  } else if (aspect == 2) {
    mask = VK_IMAGE_ASPECT_STENCIL_BIT;
  } else if (aspect == 3) {
    mask = 0;
    if (has_depth(t->format)) mask |= VK_IMAGE_ASPECT_DEPTH_BIT;
    if (has_stencil(t->format)) mask |= VK_IMAGE_ASPECT_STENCIL_BIT;
    // All of a colour format is its colour aspect; a mask of zero would be an
    // image view of nothing, which the driver accepts and then reads as zero.
    if (mask == 0) mask = VK_IMAGE_ASPECT_COLOR_BIT;
  }
  VkImageViewCreateInfo info;
  memset(&info, 0, sizeof(info));
  info.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
  info.image = t->handle;
  info.viewType = type;
  info.format = format_from_handle(format) == VK_FORMAT_UNDEFINED ? t->format
                                                                 : format_from_handle(format);
  VkImageSubresourceRange *range = &info.subresourceRange;
  range->aspectMask = mask;
  range->baseMipLevel = (uint32_t)base_mip;
  if (mip_count <= 0) {
    range->levelCount = (uint32_t)(t->mips - base_mip);
  } else {
    range->levelCount = (uint32_t)mip_count;
  }
  range->baseArrayLayer = (uint32_t)base_layer;
  if (layer_count <= 0) {
    range->layerCount = (uint32_t)(t->layers - base_layer);
  } else {
    range->layerCount = (uint32_t)layer_count;
  }
  if (failed(vkCreateImageView(t->device, &info, 0, &v->handle),
             "vkCreateImageView")) {
    free(v);
    return 0;
  }
  v->device = t->device;
  return HANDLE(v);
}

void mwg_vk_view_destroy(int64_t handle) {
  View *v = RECORD(View);
  if (!v) return;
  vkDestroyImageView(v->device, v->handle, 0);
  free(v);
}

// --- samplers ------------------------------------------------------------

static VkFilter filter_of(int32_t value) {
  return value == 1 ? VK_FILTER_LINEAR : VK_FILTER_NEAREST;
}

static VkSamplerAddressMode address_of(int32_t value) {
  switch (value) {
    case 1: return VK_SAMPLER_ADDRESS_MODE_REPEAT;
    case 2: return VK_SAMPLER_ADDRESS_MODE_MIRRORED_REPEAT;
    default: return VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
  }
}

static VkCompareOp compare_of(int32_t value) {
  switch (value) {
    case 0: return VK_COMPARE_OP_NEVER;
    case 1: return VK_COMPARE_OP_LESS;
    case 2: return VK_COMPARE_OP_EQUAL;
    case 3: return VK_COMPARE_OP_LESS_OR_EQUAL;
    case 4: return VK_COMPARE_OP_GREATER;
    case 5: return VK_COMPARE_OP_NOT_EQUAL;
    case 6: return VK_COMPARE_OP_GREATER_OR_EQUAL;
    default: return VK_COMPARE_OP_ALWAYS;
  }
}

int64_t mwg_vk_sampler_create(int64_t handle, int32_t mag, int32_t min,
                              int32_t mip, int32_t address_u,
                              int32_t address_v, int32_t address_w,
                              double lod_min, double lod_max,
                              int32_t compare_enabled, int32_t compare,
                              double anisotropy) {
  Device *d = RECORD(Device);
  if (!d) return 0;
  Sampler *s = (Sampler *)calloc(1, sizeof(Sampler));
  if (!s) {
    set_error("out of host memory for the sampler record");
    return 0;
  }
  VkSamplerCreateInfo info;
  memset(&info, 0, sizeof(info));
  info.sType = VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO;
  info.magFilter = filter_of(mag);
  info.minFilter = filter_of(min);
  info.mipmapMode =
      mip == 1 ? VK_SAMPLER_MIPMAP_MODE_LINEAR : VK_SAMPLER_MIPMAP_MODE_NEAREST;
  info.addressModeU = address_of(address_u);
  info.addressModeV = address_of(address_v);
  info.addressModeW = address_of(address_w);
  info.minLod = (float)lod_min;
  info.maxLod = (float)lod_max;
  info.compareEnable = compare_enabled ? VK_TRUE : VK_FALSE;
  info.compareOp = compare_of(compare);
  info.anisotropyEnable = anisotropy > 1.0 ? VK_TRUE : VK_FALSE;
  info.maxAnisotropy = anisotropy > 1.0 ? (float)anisotropy : 1.0f;
  info.borderColor = VK_BORDER_COLOR_FLOAT_TRANSPARENT_BLACK;
  if (failed(vkCreateSampler(d->handle, &info, 0, &s->handle),
             "vkCreateSampler")) {
    free(s);
    return 0;
  }
  s->device = d->handle;
  return HANDLE(s);
}

void mwg_vk_sampler_destroy(int64_t handle) {
  Sampler *s = RECORD(Sampler);
  if (!s) return;
  vkDestroySampler(s->device, s->handle, 0);
  free(s);
}

// --- shaders -------------------------------------------------------------

int64_t mwg_vk_shader_create(int64_t handle, const uint8_t *words,
                             int32_t bytes) {
  Device *d = RECORD(Device);
  if (!d) return 0;
  if (bytes <= 0 || (bytes % 4) != 0) {
    set_error("a SPIR-V module is a whole number of 32-bit words");
    return 0;
  }
  Shader *s = (Shader *)calloc(1, sizeof(Shader));
  if (!s) {
    set_error("out of host memory for the shader record");
    return 0;
  }
  VkShaderModuleCreateInfo info;
  memset(&info, 0, sizeof(info));
  info.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
  info.codeSize = (size_t)bytes;
  info.pCode = (const uint32_t *)words;
  if (failed(vkCreateShaderModule(d->handle, &info, 0, &s->handle),
             "vkCreateShaderModule")) {
    free(s);
    return 0;
  }
  s->device = d->handle;
  return HANDLE(s);
}

void mwg_vk_shader_destroy(int64_t handle) {
  Shader *s = RECORD(Shader);
  if (!s) return;
  vkDestroyShaderModule(s->device, s->handle, 0);
  free(s);
}

// --- descriptor set layouts ----------------------------------------------
//
// Each entry is twelve 32-bit numbers: binding, visibility, kind, count,
// dynamic, sample type, view dimension, multisampled, storage access, and three
// that are reserved (0, 0, 0).

static VkDescriptorType descriptor_type_of(int32_t kind, int32_t dynamic) {
  switch (kind) {
    case 0:
      return dynamic ? VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC
                     : VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
    case 1:
    case 2:
      return dynamic ? VK_DESCRIPTOR_TYPE_STORAGE_BUFFER_DYNAMIC
                     : VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
    case 8:
      return VK_DESCRIPTOR_TYPE_STORAGE_IMAGE;
    default:
      if (kind >= 3 && kind <= 5) return VK_DESCRIPTOR_TYPE_SAMPLER;
      return VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE;
  }
}

static VkShaderStageFlags stages_mask_of(int32_t visibility) {
  VkShaderStageFlags mask = 0;
  if (visibility & 1) mask |= VK_SHADER_STAGE_VERTEX_BIT;
  if (visibility & 2) mask |= VK_SHADER_STAGE_FRAGMENT_BIT;
  if (visibility & 4) mask |= VK_SHADER_STAGE_COMPUTE_BIT;
  return mask;
}

int64_t mwg_vk_set_layout_create(int64_t handle, const int32_t *entries,
                                 int32_t count) {
  Device *d = RECORD(Device);
  if (!d) return 0;
  if (count < 0) {
    set_error("negative descriptor count");
    return 0;
  }
  SetLayout *layout = (SetLayout *)calloc(1, sizeof(SetLayout));
  if (!layout) {
    set_error("out of host memory for the layout record");
    return 0;
  }
  VkDescriptorSetLayoutBinding *bindings = (VkDescriptorSetLayoutBinding *)calloc(
      count ? (size_t)count : 1, sizeof(VkDescriptorSetLayoutBinding));
  if (!bindings) {
    set_error("out of host memory for the bindings");
    free(layout);
    return 0;
  }
  for (int32_t i = 0; i < count; i++) {
    const int32_t *e = entries + i * 12;
    bindings[i].binding = (uint32_t)e[0];
    bindings[i].descriptorType = descriptor_type_of(e[2], e[4]);
    bindings[i].descriptorCount = e[3] > 0 ? (uint32_t)e[3] : 1u;
    bindings[i].stageFlags = stages_mask_of(e[1]);
    bindings[i].pImmutableSamplers = 0;
  }
  VkDescriptorSetLayoutCreateInfo info;
  memset(&info, 0, sizeof(info));
  info.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
  info.bindingCount = (uint32_t)count;
  info.pBindings = count ? bindings : 0;
  VkResult r = vkCreateDescriptorSetLayout(d->handle, &info, 0, &layout->handle);
  free(bindings);
  if (failed(r, "vkCreateDescriptorSetLayout")) {
    free(layout);
    return 0;
  }
  layout->device = d->handle;
  return HANDLE(layout);
}

void mwg_vk_set_layout_destroy(int64_t handle) {
  SetLayout *layout = RECORD(SetLayout);
  if (!layout) return;
  vkDestroyDescriptorSetLayout(layout->device, layout->handle, 0);
  free(layout);
}

// --- pipeline layouts ----------------------------------------------------
//
// The immediate constants of a pipeline are Vulkan's push constants, in one
// range that starts at zero and covers what the layer above accepts.

int64_t mwg_vk_pipeline_layout_create(int64_t handle, const int64_t *layouts,
                                      int32_t count) {
  Device *d = RECORD(Device);
  if (!d) return 0;
  PipelineLayout *layout = (PipelineLayout *)calloc(1, sizeof(PipelineLayout));
  if (!layout) {
    set_error("out of host memory for the pipeline layout record");
    return 0;
  }
  VkDescriptorSetLayout *sets = (VkDescriptorSetLayout *)calloc(
      count ? (size_t)count : 1, sizeof(VkDescriptorSetLayout));
  if (!sets) {
    set_error("out of host memory for the set layout list");
    free(layout);
    return 0;
  }
  for (int32_t i = 0; i < count; i++) {
    SetLayout *one = AT(SetLayout, layouts[i]);
    if (!one) {
      set_error("pipeline layout names a set layout that does not exist");
      free(sets);
      free(layout);
      return 0;
    }
    sets[i] = one->handle;
  }
  VkPushConstantRange range;
  memset(&range, 0, sizeof(range));
  range.stageFlags = VK_SHADER_STAGE_ALL;
  range.offset = 0;
  range.size = 128;
  VkPipelineLayoutCreateInfo info;
  memset(&info, 0, sizeof(info));
  info.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
  info.setLayoutCount = (uint32_t)count;
  info.pSetLayouts = count ? sets : 0;
  info.pushConstantRangeCount = 1;
  info.pPushConstantRanges = &range;
  VkResult r = vkCreatePipelineLayout(d->handle, &info, 0, &layout->handle);
  free(sets);
  if (failed(r, "vkCreatePipelineLayout")) {
    free(layout);
    return 0;
  }
  layout->device = d->handle;
  return HANDLE(layout);
}

void mwg_vk_pipeline_layout_destroy(int64_t handle) {
  PipelineLayout *layout = RECORD(PipelineLayout);
  if (!layout) return;
  vkDestroyPipelineLayout(layout->device, layout->handle, 0);
  free(layout);
}

// --- descriptor sets -----------------------------------------------------

int64_t mwg_vk_set_create(int64_t handle, int64_t set_layout) {
  Device *d = RECORD(Device);
  SetLayout *layout = AT(SetLayout, set_layout);
  if (!d || !layout) {
    set_error("descriptor set for a layout that does not exist");
    return 0;
  }
  Set *set = (Set *)calloc(1, sizeof(Set));
  if (!set) {
    set_error("out of host memory for the descriptor set record");
    return 0;
  }
  VkDescriptorSetAllocateInfo info;
  memset(&info, 0, sizeof(info));
  info.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO;
  info.descriptorPool = d->descriptors;
  info.descriptorSetCount = 1;
  info.pSetLayouts = &layout->handle;
  if (failed(vkAllocateDescriptorSets(d->handle, &info, &set->handle),
             "vkAllocateDescriptorSets")) {
    free(set);
    return 0;
  }
  set->device = d->handle;
  set->pool = d->descriptors;
  set->layout = layout->handle;
  return HANDLE(set);
}

void mwg_vk_set_destroy(int64_t handle) {
  Set *set = RECORD(Set);
  if (!set) return;
  vkFreeDescriptorSets(set->device, set->pool, 1, &set->handle);
  free(set);
}

static int write_buffer(Set *set, int32_t binding, int32_t count, int64_t buffer,
                        int32_t offset, int32_t size, VkDescriptorType type) {
  Buffer *b = AT(Buffer, buffer);
  if (!b) {
    set_error("descriptor set names a buffer that does not exist");
    return 0;
  }
  VkDescriptorBufferInfo range;
  range.buffer = b->handle;
  range.offset = (VkDeviceSize)offset;
  range.range = size > 0 ? (VkDeviceSize)size : VK_WHOLE_SIZE;
  VkWriteDescriptorSet write;
  memset(&write, 0, sizeof(write));
  write.sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
  write.dstSet = set->handle;
  write.dstBinding = (uint32_t)binding;
  write.descriptorCount = count > 0 ? (uint32_t)count : 1u;
  write.descriptorType = type;
  write.pBufferInfo = &range;
  vkUpdateDescriptorSets(set->device, 1, &write, 0, 0);
  return 1;
}

int32_t mwg_vk_set_buffer(int64_t handle, int32_t binding, int64_t buffer,
                          int32_t offset, int32_t size, int32_t kind) {
  Set *set = RECORD(Set);
  if (!set) return 0;
  VkDescriptorType type = kind == 0 ? VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER
                                    : VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
  return write_buffer(set, binding, 1, buffer, offset, size, type);
}

int32_t mwg_vk_set_sampler(int64_t handle, int32_t binding, int64_t sampler) {
  Set *set = RECORD(Set);
  Sampler *s = AT(Sampler, sampler);
  if (!set || !s) return 0;
  VkDescriptorImageInfo image;
  memset(&image, 0, sizeof(image));
  image.sampler = s->handle;
  VkWriteDescriptorSet write;
  memset(&write, 0, sizeof(write));
  write.sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
  write.dstSet = set->handle;
  write.dstBinding = (uint32_t)binding;
  write.descriptorCount = 1;
  write.descriptorType = VK_DESCRIPTOR_TYPE_SAMPLER;
  write.pImageInfo = &image;
  vkUpdateDescriptorSets(set->device, 1, &write, 0, 0);
  return 1;
}

int32_t mwg_vk_set_texture(int64_t handle, int32_t binding, int64_t view,
                           int32_t kind) {
  Set *set = RECORD(Set);
  View *v = AT(View, view);
  if (!set || !v) return 0;
  VkDescriptorImageInfo image;
  memset(&image, 0, sizeof(image));
  image.imageView = v->handle;
  image.imageLayout = kind == 1 ? VK_IMAGE_LAYOUT_GENERAL
                                : VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
  VkWriteDescriptorSet write;
  memset(&write, 0, sizeof(write));
  write.sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
  write.dstSet = set->handle;
  write.dstBinding = (uint32_t)binding;
  write.descriptorCount = 1;
  write.descriptorType =
      kind == 1 ? VK_DESCRIPTOR_TYPE_STORAGE_IMAGE : VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE;
  write.pImageInfo = &image;
  vkUpdateDescriptorSets(set->device, 1, &write, 0, 0);
  return 1;
}

// --- pipelines -----------------------------------------------------------
//
// A graphics pipeline is built for dynamic rendering: the attachment formats
// travel in `VkPipelineRenderingCreateInfo` instead of a render pass object, so
// a pipeline and the pass that uses it need no shared description.

static VkPrimitiveTopology topology_of(int32_t value) {
  switch (value) {
    case 0: return VK_PRIMITIVE_TOPOLOGY_POINT_LIST;
    case 1: return VK_PRIMITIVE_TOPOLOGY_LINE_LIST;
    case 2: return VK_PRIMITIVE_TOPOLOGY_LINE_STRIP;
    case 3: return VK_PRIMITIVE_TOPOLOGY_TRIANGLE_STRIP;
    default: return VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
  }
}

static VkBlendFactor blend_factor_of(int32_t value) {
  switch (value) {
    case 0: return VK_BLEND_FACTOR_ZERO;
    case 1: return VK_BLEND_FACTOR_ONE;
    case 2: return VK_BLEND_FACTOR_SRC_COLOR;
    case 3: return VK_BLEND_FACTOR_ONE_MINUS_SRC_COLOR;
    case 4: return VK_BLEND_FACTOR_SRC_ALPHA;
    case 5: return VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA;
    case 6: return VK_BLEND_FACTOR_DST_COLOR;
    case 7: return VK_BLEND_FACTOR_ONE_MINUS_DST_COLOR;
    case 8: return VK_BLEND_FACTOR_DST_ALPHA;
    case 9: return VK_BLEND_FACTOR_ONE_MINUS_DST_ALPHA;
    case 10: return VK_BLEND_FACTOR_SRC_ALPHA_SATURATE;
    case 11: return VK_BLEND_FACTOR_CONSTANT_COLOR;
    case 12: return VK_BLEND_FACTOR_ONE_MINUS_CONSTANT_COLOR;
    case 13: return VK_BLEND_FACTOR_SRC1_COLOR;
    case 14: return VK_BLEND_FACTOR_ONE_MINUS_SRC1_COLOR;
    case 15: return VK_BLEND_FACTOR_SRC1_ALPHA;
    default: return VK_BLEND_FACTOR_ONE_MINUS_SRC1_ALPHA;
  }
}

static VkBlendOp blend_op_of(int32_t value) {
  switch (value) {
    case 1: return VK_BLEND_OP_SUBTRACT;
    case 2: return VK_BLEND_OP_REVERSE_SUBTRACT;
    case 3: return VK_BLEND_OP_MIN;
    case 4: return VK_BLEND_OP_MAX;
    default: return VK_BLEND_OP_ADD;
  }
}

static VkStencilOp stencil_op_of(int32_t value) {
  switch (value) {
    case 1: return VK_STENCIL_OP_ZERO;
    case 2: return VK_STENCIL_OP_REPLACE;
    case 3: return VK_STENCIL_OP_INVERT;
    case 4: return VK_STENCIL_OP_INCREMENT_AND_CLAMP;
    case 5: return VK_STENCIL_OP_DECREMENT_AND_CLAMP;
    case 6: return VK_STENCIL_OP_INCREMENT_AND_WRAP;
    case 7: return VK_STENCIL_OP_DECREMENT_AND_WRAP;
    default: return VK_STENCIL_OP_KEEP;
  }
}

static VkVertexInputRate step_mode_of(int32_t value) {
  return value == 1 ? VK_VERTEX_INPUT_RATE_INSTANCE : VK_VERTEX_INPUT_RATE_VERTEX;
}

int64_t mwg_vk_render_pipeline_create(
    int64_t handle, int64_t pipeline_layout, int64_t vertex_shader,
    const uint8_t *vertex_entry, int32_t vertex_entry_length,
    int64_t fragment_shader, const uint8_t *fragment_entry,
    int32_t fragment_entry_length, const int32_t *stream, int32_t count,
    int32_t bias_constant, double bias_slope, double bias_clamp) {
  Device *d = RECORD(Device);
  PipelineLayout *layout = AT(PipelineLayout, pipeline_layout);
  Shader *vertex = AT(Shader, vertex_shader);
  Shader *fragment = AT(Shader, fragment_shader);
  if (!d || !layout || !vertex || !fragment) {
    set_error("render pipeline names a shader or a layout that does not exist");
    return 0;
  }
  char vertex_name[128];
  char fragment_name[128];
  int32_t vn = vertex_entry_length < 127 ? vertex_entry_length : 127;
  int32_t fn = fragment_entry_length < 127 ? fragment_entry_length : 127;
  memcpy(vertex_name, vertex_entry, (size_t)vn);
  vertex_name[vn] = 0;
  memcpy(fragment_name, fragment_entry, (size_t)fn);
  fragment_name[fn] = 0;
  int32_t at = 0;
  VkPrimitiveTopology topology = topology_of(stream[at++]);
  int32_t front_face = stream[at++];
  int32_t cull = stream[at++];
  int32_t strip_format = stream[at++];
  int32_t unclipped = stream[at++];
  int32_t buffer_count = stream[at++];
  VkVertexInputBindingDescription *bindings =
      (VkVertexInputBindingDescription *)calloc(
          buffer_count ? (size_t)buffer_count : 1,
          sizeof(VkVertexInputBindingDescription));
  int32_t attribute_capacity = 0;
  for (int32_t i = 0; i < buffer_count; i++) {
    int32_t index = at + i * 3;
    attribute_capacity += stream[index + 2];
  }
  VkVertexInputAttributeDescription *attributes =
      (VkVertexInputAttributeDescription *)calloc(
          attribute_capacity ? (size_t)attribute_capacity : 1,
          sizeof(VkVertexInputAttributeDescription));
  if (!bindings || !attributes) {
    set_error("out of host memory for the vertex input");
    free(bindings);
    free(attributes);
    return 0;
  }
  int32_t attribute_count = 0;
  for (int32_t i = 0; i < buffer_count; i++) {
    bindings[i].binding = (uint32_t)i;
    bindings[i].stride = (uint32_t)stream[at];
    bindings[i].inputRate = step_mode_of(stream[at + 1]);
    int32_t attributes_here = stream[at + 2];
    at += 3;
    for (int32_t a = 0; a < attributes_here; a++) {
      attributes[attribute_count].location = (uint32_t)stream[at];
      attributes[attribute_count].format = format_from_handle(stream[at + 1]);
      attributes[attribute_count].offset = (uint32_t)stream[at + 2];
      attributes[attribute_count].binding = (uint32_t)i;
      attribute_count++;
      at += 3;
    }
  }
  int32_t color_count = stream[at++];
  VkPipelineColorBlendAttachmentState *blends =
      (VkPipelineColorBlendAttachmentState *)calloc(
          color_count ? (size_t)color_count : 1,
          sizeof(VkPipelineColorBlendAttachmentState));
  VkFormat *color_formats =
      (VkFormat *)calloc(color_count ? (size_t)color_count : 1, sizeof(VkFormat));
  if (!blends || !color_formats) {
    set_error("out of host memory for the colour targets");
    free(bindings);
    free(attributes);
    free(blends);
    free(color_formats);
    return 0;
  }
  for (int32_t i = 0; i < color_count; i++) {
    color_formats[i] = format_from_handle(stream[at]);
    blends[i].blendEnable = stream[at + 1] ? VK_TRUE : VK_FALSE;
    blends[i].srcColorBlendFactor = blend_factor_of(stream[at + 2]);
    blends[i].dstColorBlendFactor = blend_factor_of(stream[at + 3]);
    blends[i].colorBlendOp = blend_op_of(stream[at + 4]);
    blends[i].srcAlphaBlendFactor = blend_factor_of(stream[at + 5]);
    blends[i].dstAlphaBlendFactor = blend_factor_of(stream[at + 6]);
    blends[i].alphaBlendOp = blend_op_of(stream[at + 7]);
    blends[i].colorWriteMask = (VkColorComponentFlags)stream[at + 8];
    at += 9;
  }
  int32_t has_depth_attachment = stream[at++];
  VkFormat depth_format = format_from_handle(stream[at++]);
  int32_t depth_write = stream[at++];
  int32_t depth_compare = stream[at++];
  int32_t front_compare = stream[at++];
  int32_t front_fail = stream[at++];
  int32_t front_depth_fail = stream[at++];
  int32_t front_pass = stream[at++];
  int32_t back_compare = stream[at++];
  int32_t back_fail = stream[at++];
  int32_t back_depth_fail = stream[at++];
  int32_t back_pass = stream[at++];
  int32_t stencil_read = stream[at++];
  int32_t stencil_write = stream[at++];
  int32_t samples = stream[at++];
  uint32_t sample_mask = (uint32_t)stream[at++];
  int32_t alpha_to_coverage = stream[at++];
  if (at > count) {
    set_error("the render pipeline description is shorter than its content");
    free(bindings);
    free(attributes);
    free(blends);
    free(color_formats);
    return 0;
  }
  VkPipelineShaderStageCreateInfo stages[2];
  memset(stages, 0, sizeof(stages));
  stages[0].sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
  stages[0].stage = VK_SHADER_STAGE_VERTEX_BIT;
  stages[0].module = vertex->handle;
  stages[0].pName = vertex_name;
  stages[1].sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
  stages[1].stage = VK_SHADER_STAGE_FRAGMENT_BIT;
  stages[1].module = fragment->handle;
  stages[1].pName = fragment_name;
  VkPipelineVertexInputStateCreateInfo vertex_input;
  memset(&vertex_input, 0, sizeof(vertex_input));
  vertex_input.sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;
  vertex_input.vertexBindingDescriptionCount = (uint32_t)buffer_count;
  vertex_input.pVertexBindingDescriptions = buffer_count ? bindings : 0;
  vertex_input.vertexAttributeDescriptionCount = (uint32_t)attribute_count;
  vertex_input.pVertexAttributeDescriptions = attribute_count ? attributes : 0;
  VkPipelineInputAssemblyStateCreateInfo assembly;
  memset(&assembly, 0, sizeof(assembly));
  assembly.sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
  assembly.topology = topology;
  assembly.primitiveRestartEnable = VK_FALSE;
  (void)strip_format;
  VkPipelineViewportStateCreateInfo viewport_state;
  memset(&viewport_state, 0, sizeof(viewport_state));
  viewport_state.sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
  viewport_state.viewportCount = 1;
  viewport_state.scissorCount = 1;
  VkPipelineRasterizationStateCreateInfo raster;
  memset(&raster, 0, sizeof(raster));
  raster.sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
  raster.depthClampEnable = unclipped ? VK_TRUE : VK_FALSE;
  raster.rasterizerDiscardEnable = VK_FALSE;
  raster.polygonMode = VK_POLYGON_MODE_FILL;
  raster.cullMode = cull == 1   ? VK_CULL_MODE_FRONT_BIT
                    : cull == 2 ? VK_CULL_MODE_BACK_BIT
                                : VK_CULL_MODE_NONE;
  raster.frontFace =
      front_face == 1 ? VK_FRONT_FACE_CLOCKWISE : VK_FRONT_FACE_COUNTER_CLOCKWISE;
  raster.depthBiasEnable =
      (bias_constant != 0 || bias_slope != 0.0 || bias_clamp != 0.0) ? VK_TRUE
                                                                    : VK_FALSE;
  raster.depthBiasConstantFactor = (float)bias_constant;
  raster.depthBiasSlopeFactor = (float)bias_slope;
  raster.depthBiasClamp = (float)bias_clamp;
  raster.lineWidth = 1.0f;
  VkPipelineMultisampleStateCreateInfo multisample;
  memset(&multisample, 0, sizeof(multisample));
  multisample.sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
  multisample.rasterizationSamples =
      (VkSampleCountFlagBits)(samples > 0 ? samples : 1);
  multisample.sampleShadingEnable = VK_FALSE;
  multisample.alphaToCoverageEnable = alpha_to_coverage ? VK_TRUE : VK_FALSE;
  multisample.pSampleMask = &sample_mask;
  VkPipelineDepthStencilStateCreateInfo depth;
  memset(&depth, 0, sizeof(depth));
  depth.sType = VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO;
  depth.depthTestEnable = has_depth_attachment ? VK_TRUE : VK_FALSE;
  depth.depthWriteEnable = (has_depth_attachment && depth_write) ? VK_TRUE : VK_FALSE;
  depth.depthCompareOp = compare_of(depth_compare);
  depth.depthBoundsTestEnable = VK_FALSE;
  depth.stencilTestEnable = has_depth_attachment ? VK_TRUE : VK_FALSE;
  depth.front.failOp = stencil_op_of(front_fail);
  depth.front.passOp = stencil_op_of(front_pass);
  depth.front.depthFailOp = stencil_op_of(front_depth_fail);
  depth.front.compareOp = compare_of(front_compare);
  depth.front.compareMask = (uint32_t)stencil_read;
  depth.front.writeMask = (uint32_t)stencil_write;
  depth.front.reference = 0;
  depth.back.failOp = stencil_op_of(back_fail);
  depth.back.passOp = stencil_op_of(back_pass);
  depth.back.depthFailOp = stencil_op_of(back_depth_fail);
  depth.back.compareOp = compare_of(back_compare);
  depth.back.compareMask = (uint32_t)stencil_read;
  depth.back.writeMask = (uint32_t)stencil_write;
  depth.back.reference = 0;
  depth.minDepthBounds = 0.0f;
  depth.maxDepthBounds = 1.0f;
  VkPipelineColorBlendStateCreateInfo blend_state;
  memset(&blend_state, 0, sizeof(blend_state));
  blend_state.sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
  blend_state.attachmentCount = (uint32_t)color_count;
  blend_state.pAttachments = color_count ? blends : 0;
  VkDynamicState dynamic[] = {VK_DYNAMIC_STATE_VIEWPORT, VK_DYNAMIC_STATE_SCISSOR,
                              VK_DYNAMIC_STATE_BLEND_CONSTANTS,
                              VK_DYNAMIC_STATE_STENCIL_REFERENCE};
  VkPipelineDynamicStateCreateInfo dynamic_state;
  memset(&dynamic_state, 0, sizeof(dynamic_state));
  dynamic_state.sType = VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO;
  dynamic_state.dynamicStateCount = 4;
  dynamic_state.pDynamicStates = dynamic;
  VkPipelineRenderingCreateInfo rendering;
  memset(&rendering, 0, sizeof(rendering));
  rendering.sType = VK_STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO;
  rendering.colorAttachmentCount = (uint32_t)color_count;
  rendering.pColorAttachmentFormats = color_count ? color_formats : 0;
  rendering.depthAttachmentFormat =
      has_depth_attachment && has_depth(depth_format) ? depth_format
                                                      : VK_FORMAT_UNDEFINED;
  rendering.stencilAttachmentFormat =
      has_depth_attachment && has_stencil(depth_format) ? depth_format
                                                        : VK_FORMAT_UNDEFINED;
  VkGraphicsPipelineCreateInfo info;
  memset(&info, 0, sizeof(info));
  info.sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
  info.pNext = &rendering;
  info.stageCount = 2;
  info.pStages = stages;
  info.pVertexInputState = &vertex_input;
  info.pInputAssemblyState = &assembly;
  info.pViewportState = &viewport_state;
  info.pRasterizationState = &raster;
  info.pMultisampleState = &multisample;
  info.pDepthStencilState = &depth;
  info.pColorBlendState = &blend_state;
  info.pDynamicState = &dynamic_state;
  info.layout = layout->handle;
  VkPipeline pipeline_handle;
  VkResult r =
      vkCreateGraphicsPipelines(d->handle, VK_NULL_HANDLE, 1, &info, 0,
                                &pipeline_handle);
  free(bindings);
  free(attributes);
  free(blends);
  free(color_formats);
  if (failed(r, "vkCreateGraphicsPipelines")) return 0;
  Pipeline *p = (Pipeline *)calloc(1, sizeof(Pipeline));
  if (!p) {
    vkDestroyPipeline(d->handle, pipeline_handle, 0);
    set_error("out of host memory for the pipeline record");
    return 0;
  }
  p->device = d->handle;
  p->handle = pipeline_handle;
  p->bind_point = VK_PIPELINE_BIND_POINT_GRAPHICS;
  p->layout = layout->handle;
  return HANDLE(p);
}

int64_t mwg_vk_compute_pipeline_create(int64_t handle,
                                       int64_t pipeline_layout,
                                       int64_t compute_shader,
                                       const uint8_t *entry,
                                       int32_t entry_length) {
  Device *d = RECORD(Device);
  PipelineLayout *layout = AT(PipelineLayout, pipeline_layout);
  Shader *shader = AT(Shader, compute_shader);
  if (!d || !layout || !shader) {
    set_error("compute pipeline names a shader or a layout that does not exist");
    return 0;
  }
  char name[128];
  int32_t n = entry_length < 127 ? entry_length : 127;
  memcpy(name, entry, (size_t)n);
  name[n] = 0;
  VkComputePipelineCreateInfo info;
  memset(&info, 0, sizeof(info));
  info.sType = VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO;
  info.stage.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
  info.stage.stage = VK_SHADER_STAGE_COMPUTE_BIT;
  info.stage.module = shader->handle;
  info.stage.pName = name;
  info.layout = layout->handle;
  VkPipeline pipeline_handle;
  if (failed(vkCreateComputePipelines(d->handle, VK_NULL_HANDLE, 1, &info, 0,
                                      &pipeline_handle),
             "vkCreateComputePipelines"))
    return 0;
  Pipeline *p = (Pipeline *)calloc(1, sizeof(Pipeline));
  if (!p) {
    vkDestroyPipeline(d->handle, pipeline_handle, 0);
    set_error("out of host memory for the pipeline record");
    return 0;
  }
  p->device = d->handle;
  p->handle = pipeline_handle;
  p->bind_point = VK_PIPELINE_BIND_POINT_COMPUTE;
  p->layout = layout->handle;
  return HANDLE(p);
}

void mwg_vk_pipeline_destroy(int64_t handle) {
  Pipeline *p = RECORD(Pipeline);
  if (!p) return;
  vkDestroyPipeline(p->device, p->handle, 0);
  free(p);
}

// --- query sets ----------------------------------------------------------

int64_t mwg_vk_queries_create(int64_t handle, int32_t kind, int32_t count) {
  Device *d = RECORD(Device);
  if (!d || count <= 0) return 0;
  Queries *q = (Queries *)calloc(1, sizeof(Queries));
  if (!q) {
    set_error("out of host memory for the query record");
    return 0;
  }
  VkQueryPoolCreateInfo info;
  memset(&info, 0, sizeof(info));
  info.sType = VK_STRUCTURE_TYPE_QUERY_POOL_CREATE_INFO;
  info.queryType =
      kind == 1 ? VK_QUERY_TYPE_TIMESTAMP : VK_QUERY_TYPE_OCCLUSION;
  info.queryCount = (uint32_t)count;
  if (kind == 0) info.pipelineStatistics = 0;
  if (failed(vkCreateQueryPool(d->handle, &info, 0, &q->handle),
             "vkCreateQueryPool")) {
    free(q);
    return 0;
  }
  q->device = d->handle;
  q->count = count;
  q->timestamps = kind == 1;
  return HANDLE(q);
}

void mwg_vk_queries_destroy(int64_t handle) {
  Queries *q = RECORD(Queries);
  if (!q) return;
  vkDestroyQueryPool(q->device, q->handle, 0);
  free(q);
}

// --- recording -----------------------------------------------------------
//
// One command buffer per submission. The layer above records a pass at a time;
// this side keeps the buffer open between calls and submits when told.

int32_t mwg_vk_record_begin(int64_t handle) {
  Device *d = RECORD(Device);
  if (!d) return 0;
  if (d->recording) {
    set_error("a submission is already being recorded");
    return 0;
  }
  VkCommandBufferBeginInfo begin;
  memset(&begin, 0, sizeof(begin));
  begin.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
  begin.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
  if (failed(vkResetCommandBuffer(d->command, 0), "vkResetCommandBuffer") ||
      failed(vkBeginCommandBuffer(d->command, &begin), "vkBeginCommandBuffer"))
    return 0;
  d->recording = 1;
  return 1;
}

int32_t mwg_vk_record_submit(int64_t handle) {
  Device *d = RECORD(Device);
  if (!d || !d->recording) return 0;
  d->recording = 0;
  if (failed(vkEndCommandBuffer(d->command), "vkEndCommandBuffer")) return 0;
  VkSubmitInfo submit;
  memset(&submit, 0, sizeof(submit));
  submit.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
  submit.commandBufferCount = 1;
  submit.pCommandBuffers = &d->command;
  if (failed(vkQueueSubmit(d->queue, 1, &submit, VK_NULL_HANDLE),
             "vkQueueSubmit"))
    return 0;
  // The device timeline of this library is the caller's: a submission is
  // finished when `submit` returns.
  return failed(vkQueueWaitIdle(d->queue), "vkQueueWaitIdle") ? 0 : 1;
}

void mwg_vk_record_abandon(int64_t handle) {
  Device *d = RECORD(Device);
  if (!d || !d->recording) return;
  d->recording = 0;
  vkEndCommandBuffer(d->command);
}

int32_t mwg_vk_begin_render(int64_t handle, int32_t width, int32_t height,
                            int32_t color_count, const int64_t *views,
                            const int64_t *formats, const int32_t *loads,
                            const int32_t *stores, const double *clears,
                            int64_t depth_view, int64_t depth_format,
                            int32_t depth_load, int32_t depth_store,
                            double depth_clear, int32_t stencil_clear,
                            int32_t depth_read_only) {
  Device *d = RECORD(Device);
  if (!d || !d->recording) {
    set_error("a render pass before recording began");
    return 0;
  }
  VkRenderingAttachmentInfo *colors =
      (VkRenderingAttachmentInfo *)calloc(
          color_count ? (size_t)color_count : 1,
          sizeof(VkRenderingAttachmentInfo));
  if (!colors) {
    set_error("out of host memory for the attachments");
    return 0;
  }
  for (int32_t i = 0; i < color_count; i++) {
    View *v = AT(View, views[i]);
    if (!v) {
      set_error("colour attachment names a view that does not exist");
      free(colors);
      return 0;
    }
    colors[i].sType = VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO;
    colors[i].imageView = v->handle;
    colors[i].imageLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
    colors[i].loadOp = loads[i] ? VK_ATTACHMENT_LOAD_OP_CLEAR
                                : VK_ATTACHMENT_LOAD_OP_LOAD;
    colors[i].storeOp =
        stores[i] ? VK_ATTACHMENT_STORE_OP_DONT_CARE : VK_ATTACHMENT_STORE_OP_STORE;
    colors[i].clearValue.color.float32[0] = (float)clears[i * 4];
    colors[i].clearValue.color.float32[1] = (float)clears[i * 4 + 1];
    colors[i].clearValue.color.float32[2] = (float)clears[i * 4 + 2];
    colors[i].clearValue.color.float32[3] = (float)clears[i * 4 + 3];
    if (formats[i] == (int64_t)VK_FORMAT_R32_UINT ||
        formats[i] == (int64_t)VK_FORMAT_R32_SINT) {
      // Integer attachments clear with the bit pattern, not the float.
      colors[i].clearValue.color.uint32[0] = (uint32_t)clears[i * 4];
      colors[i].clearValue.color.uint32[1] = (uint32_t)clears[i * 4 + 1];
      colors[i].clearValue.color.uint32[2] = (uint32_t)clears[i * 4 + 2];
      colors[i].clearValue.color.uint32[3] = (uint32_t)clears[i * 4 + 3];
    }
  }
  VkRenderingAttachmentInfo depth;
  memset(&depth, 0, sizeof(depth));
  VkRenderingInfo info;
  memset(&info, 0, sizeof(info));
  info.sType = VK_STRUCTURE_TYPE_RENDERING_INFO;
  info.renderArea.offset.x = 0;
  info.renderArea.offset.y = 0;
  info.renderArea.extent.width = (uint32_t)(width > 0 ? width : 1);
  info.renderArea.extent.height = (uint32_t)(height > 0 ? height : 1);
  info.layerCount = 1;
  info.colorAttachmentCount = (uint32_t)color_count;
  info.pColorAttachments = color_count ? colors : 0;
  if (depth_view) {
    View *v = AT(View, depth_view);
    if (!v) {
      set_error("depth attachment names a view that does not exist");
      free(colors);
      return 0;
    }
    VkFormat format = format_from_handle(depth_format);
    depth.sType = VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO;
    depth.imageView = v->handle;
    depth.imageLayout = depth_read_only
                            ? VK_IMAGE_LAYOUT_DEPTH_STENCIL_READ_ONLY_OPTIMAL
                            : VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL;
    depth.loadOp =
        depth_load ? VK_ATTACHMENT_LOAD_OP_CLEAR : VK_ATTACHMENT_LOAD_OP_LOAD;
    depth.storeOp = depth_store ? VK_ATTACHMENT_STORE_OP_DONT_CARE
                                : VK_ATTACHMENT_STORE_OP_STORE;
    depth.clearValue.depthStencil.depth = (float)depth_clear;
    depth.clearValue.depthStencil.stencil = (uint32_t)stencil_clear;
    if (has_depth(format) && !has_stencil(format)) {
      info.pDepthAttachment = &depth;
    } else if (!has_depth(format) && has_stencil(format)) {
      info.pStencilAttachment = &depth;
    } else {
      info.pDepthAttachment = &depth;
      info.pStencilAttachment = &depth;
    }
  }
  vkCmdBeginRendering(d->command, &info);
  free(colors);
  return 1;
}

void mwg_vk_end_render(int64_t handle) {
  Device *d = RECORD(Device);
  if (!d || !d->recording) return;
  vkCmdEndRendering(d->command);
}

void mwg_vk_begin_compute(int64_t handle) {
  // A compute pass is a run of commands on the same buffer, with no render
  // pass object to open: noticing it would only add a place to forget.
  (void)handle;
}

void mwg_vk_end_compute(int64_t handle) {
  (void)handle;
}

void mwg_vk_bind_pipeline(int64_t handle, int64_t pipeline) {
  Device *d = RECORD(Device);
  Pipeline *p = AT(Pipeline, pipeline);
  if (!d || !p || !d->recording) return;
  d->current_layout = p->layout;
  vkCmdBindPipeline(d->command, p->bind_point, p->handle);
}

void mwg_vk_bind_set(int64_t handle, int32_t index, int64_t set,
                     const int32_t *offsets, int32_t count, int32_t compute) {
  Device *d = RECORD(Device);
  Set *s = AT(Set, set);
  if (!d || !s || !d->recording) return;
  vkCmdBindDescriptorSets(
      d->command,
      compute ? VK_PIPELINE_BIND_POINT_COMPUTE : VK_PIPELINE_BIND_POINT_GRAPHICS,
      d->current_layout, (uint32_t)index, 1, &s->handle, (uint32_t)count,
      (const uint32_t *)offsets);
}

void mwg_vk_push_constants(int64_t handle, int32_t offset, const uint8_t *data,
                           int32_t length, int32_t compute) {
  Device *d = RECORD(Device);
  (void)compute;
  if (!d || !d->recording) return;
  vkCmdPushConstants(d->command, d->current_layout, VK_SHADER_STAGE_ALL,
                     (uint32_t)offset, (uint32_t)length, data);
}

void mwg_vk_vertex_buffer(int64_t handle, int32_t slot, int64_t buffer,
                          int32_t offset) {
  Device *d = RECORD(Device);
  Buffer *b = AT(Buffer, buffer);
  if (!d || !b || !d->recording) return;
  VkDeviceSize at = (VkDeviceSize)offset;
  vkCmdBindVertexBuffers(d->command, (uint32_t)slot, 1, &b->handle, &at);
}

void mwg_vk_index_buffer(int64_t handle, int64_t buffer, int32_t offset,
                         int32_t format) {
  Device *d = RECORD(Device);
  Buffer *b = AT(Buffer, buffer);
  if (!d || !b || !d->recording) return;
  vkCmdBindIndexBuffer(d->command, b->handle, (VkDeviceSize)offset,
                       format == 1 ? VK_INDEX_TYPE_UINT32 : VK_INDEX_TYPE_UINT16);
}

void mwg_vk_draw(int64_t handle, int32_t vertices, int32_t instances,
                 int32_t first_vertex, int32_t first_instance) {
  Device *d = RECORD(Device);
  if (!d || !d->recording) return;
  vkCmdDraw(d->command, (uint32_t)vertices, (uint32_t)instances,
            (uint32_t)first_vertex, (uint32_t)first_instance);
}

void mwg_vk_draw_indexed(int64_t handle, int32_t indices, int32_t instances,
                         int32_t first_index, int32_t base_vertex,
                         int32_t first_instance) {
  Device *d = RECORD(Device);
  if (!d || !d->recording) return;
  vkCmdDrawIndexed(d->command, (uint32_t)indices, (uint32_t)instances,
                   (uint32_t)first_index, base_vertex, (uint32_t)first_instance);
}

void mwg_vk_draw_indirect(int64_t handle, int64_t buffer, int32_t offset,
                          int32_t indexed) {
  Device *d = RECORD(Device);
  Buffer *b = AT(Buffer, buffer);
  if (!d || !b || !d->recording) return;
  if (indexed) {
    vkCmdDrawIndexedIndirect(d->command, b->handle, (VkDeviceSize)offset, 1,
                             (uint32_t)sizeof(VkDrawIndexedIndirectCommand));
  } else {
    vkCmdDrawIndirect(d->command, b->handle, (VkDeviceSize)offset, 1,
                      (uint32_t)sizeof(VkDrawIndirectCommand));
  }
}

void mwg_vk_dispatch(int64_t handle, int32_t x, int32_t y, int32_t z) {
  Device *d = RECORD(Device);
  if (!d || !d->recording) return;
  vkCmdDispatch(d->command, (uint32_t)x, (uint32_t)y, (uint32_t)z);
}

void mwg_vk_dispatch_indirect(int64_t handle, int64_t buffer, int32_t offset) {
  Device *d = RECORD(Device);
  Buffer *b = AT(Buffer, buffer);
  if (!d || !b || !d->recording) return;
  vkCmdDispatchIndirect(d->command, b->handle, (VkDeviceSize)offset);
}

void mwg_vk_viewport(int64_t handle, double x, double y, double width,
                     double height, double min_depth, double max_depth) {
  Device *d = RECORD(Device);
  if (!d || !d->recording) return;
  VkViewport viewport;
  viewport.x = (float)x;
  viewport.y = (float)y;
  viewport.width = (float)width;
  viewport.height = (float)height;
  viewport.minDepth = (float)min_depth;
  viewport.maxDepth = (float)max_depth;
  vkCmdSetViewport(d->command, 0, 1, &viewport);
}

void mwg_vk_scissor(int64_t handle, int32_t x, int32_t y, int32_t width,
                    int32_t height) {
  Device *d = RECORD(Device);
  if (!d || !d->recording) return;
  VkRect2D scissor;
  scissor.offset.x = x;
  scissor.offset.y = y;
  scissor.extent.width = (uint32_t)width;
  scissor.extent.height = (uint32_t)height;
  vkCmdSetScissor(d->command, 0, 1, &scissor);
}

void mwg_vk_blend_constants(int64_t handle, double r, double g, double b,
                            double a) {
  Device *d = RECORD(Device);
  if (!d || !d->recording) return;
  float values[4];
  values[0] = (float)r;
  values[1] = (float)g;
  values[2] = (float)b;
  values[3] = (float)a;
  vkCmdSetBlendConstants(d->command, values);
}

void mwg_vk_stencil_reference(int64_t handle, int32_t reference) {
  Device *d = RECORD(Device);
  if (!d || !d->recording) return;
  vkCmdSetStencilReference(d->command, VK_STENCIL_FACE_FRONT_AND_BACK,
                           (uint32_t)reference);
}

void mwg_vk_begin_query(int64_t handle, int64_t queries, int32_t index) {
  Device *d = RECORD(Device);
  Queries *q = AT(Queries, queries);
  if (!d || !q || !d->recording) return;
  vkCmdBeginQuery(d->command, q->handle, (uint32_t)index, 0);
}

void mwg_vk_end_query(int64_t handle, int64_t queries, int32_t index) {
  Device *d = RECORD(Device);
  Queries *q = AT(Queries, queries);
  if (!d || !q || !d->recording) return;
  vkCmdEndQuery(d->command, q->handle, (uint32_t)index);
}

void mwg_vk_write_timestamp(int64_t handle, int64_t queries, int32_t index) {
  Device *d = RECORD(Device);
  Queries *q = AT(Queries, queries);
  if (!d || !q || !d->recording) return;
  vkCmdWriteTimestamp(d->command, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, q->handle,
                      (uint32_t)index);
}

void mwg_vk_resolve_queries(int64_t handle, int64_t queries, int32_t first,
                            int32_t count, int64_t buffer, int32_t offset) {
  Device *d = RECORD(Device);
  Queries *q = AT(Queries, queries);
  Buffer *b = AT(Buffer, buffer);
  if (!d || !q || !b || !d->recording) return;
  vkCmdCopyQueryPoolResults(d->command, q->handle, (uint32_t)first,
                            (uint32_t)count, b->handle, (VkDeviceSize)offset,
                            (VkDeviceSize)(q->timestamps ? 8 : 4),
                            VK_QUERY_RESULT_64_BIT | VK_QUERY_RESULT_WAIT_BIT);
}

// --- barriers ------------------------------------------------------------

void mwg_vk_barrier(int64_t handle, int64_t texture, int32_t mip,
                    int32_t base_layer, int32_t layer_count, int32_t old_layout,
                    int32_t new_layout, int32_t from_use, int32_t to_use) {
  Device *d = RECORD(Device);
  Texture *t = AT(Texture, texture);
  if (!d || !t || !d->recording) return;
  VkImageMemoryBarrier barrier;
  memset(&barrier, 0, sizeof(barrier));
  barrier.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
  barrier.oldLayout = layout_of(old_layout);
  barrier.newLayout = layout_of(new_layout);
  barrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
  barrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
  barrier.image = t->handle;
  barrier.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
  if (has_depth(t->format)) barrier.subresourceRange.aspectMask = VK_IMAGE_ASPECT_DEPTH_BIT;
  if (has_stencil(t->format)) barrier.subresourceRange.aspectMask |= VK_IMAGE_ASPECT_STENCIL_BIT;
  barrier.subresourceRange.baseMipLevel = (uint32_t)mip;
  barrier.subresourceRange.levelCount = 1;
  barrier.subresourceRange.baseArrayLayer = (uint32_t)base_layer;
  barrier.subresourceRange.layerCount = layer_count > 0 ? (uint32_t)layer_count : 1;
  barrier.srcAccessMask = accesses_of(from_use);
  barrier.dstAccessMask = accesses_of(to_use);
  vkCmdPipelineBarrier(d->command, stages_of(from_use), stages_of(to_use), 0, 0,
                       0, 0, 0, 1, &barrier);
}

// --- copies --------------------------------------------------------------

void mwg_vk_copy_buffer(int64_t handle, int64_t source, int32_t source_offset,
                        int64_t destination, int32_t destination_offset,
                        int32_t size) {
  Device *d = RECORD(Device);
  Buffer *s = AT(Buffer, source);
  Buffer *t = AT(Buffer, destination);
  if (!d || !s || !t || !d->recording) return;
  VkBufferCopy copy;
  copy.srcOffset = (VkDeviceSize)source_offset;
  copy.dstOffset = (VkDeviceSize)destination_offset;
  copy.size = (VkDeviceSize)size;
  vkCmdCopyBuffer(d->command, s->handle, t->handle, 1, &copy);
}

void mwg_vk_fill_buffer(int64_t handle, int64_t buffer, int32_t offset,
                        int32_t size, int32_t value) {
  Device *d = RECORD(Device);
  Buffer *b = AT(Buffer, buffer);
  if (!d || !b || !d->recording) return;
  vkCmdFillBuffer(d->command, b->handle, (VkDeviceSize)offset,
                  size < 0 ? VK_WHOLE_SIZE : (VkDeviceSize)size,
                  (uint32_t)value);
}

void mwg_vk_clear_texture(int64_t handle, int64_t texture, int32_t mip,
                          int32_t x, int32_t y, int32_t z, int32_t width,
                          int32_t height, int32_t depth, int32_t is_float,
                          const double *color, const int32_t *uint_color,
                          double depth_value, int32_t stencil_value,
                          int32_t stencil_only) {
  Device *d = RECORD(Device);
  Texture *t = AT(Texture, texture);
  if (!d || !t || !d->recording) return;
  VkImageSubresourceRange range;
  range.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
  if (stencil_only) range.aspectMask = VK_IMAGE_ASPECT_STENCIL_BIT;
  else if (has_depth(t->format)) {
    range.aspectMask = VK_IMAGE_ASPECT_DEPTH_BIT;
    if (has_stencil(t->format)) range.aspectMask |= VK_IMAGE_ASPECT_STENCIL_BIT;
  }
  range.baseMipLevel = (uint32_t)mip;
  range.levelCount = 1;
  range.baseArrayLayer = (uint32_t)z;
  range.layerCount = (uint32_t)(depth > 0 ? depth : 1);
  int32_t full = x == 0 && y == 0 && width == t->width && height == t->height;
  if (range.aspectMask == VK_IMAGE_ASPECT_COLOR_BIT) {
    VkClearColorValue value;
    if (is_float) {
      value.float32[0] = (float)color[0];
      value.float32[1] = (float)color[1];
      value.float32[2] = (float)color[2];
      value.float32[3] = (float)color[3];
    } else {
      value.uint32[0] = (uint32_t)uint_color[0];
      value.uint32[1] = (uint32_t)uint_color[1];
      value.uint32[2] = (uint32_t)uint_color[2];
      value.uint32[3] = (uint32_t)uint_color[3];
    }
    if (full) {
      vkCmdClearColorImage(d->command, t->handle, VK_IMAGE_LAYOUT_GENERAL,
                           &value, 1, &range);
      return;
    }
    // A rectangle smaller than the subresource clears through a pass whose
    // render area is that rectangle: a clear operation writes only inside it.
    VkImageViewCreateInfo view_info;
    memset(&view_info, 0, sizeof(view_info));
    view_info.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
    view_info.image = t->handle;
    view_info.viewType = VK_IMAGE_VIEW_TYPE_2D;
    view_info.format = t->format;
    view_info.subresourceRange = range;
    view_info.subresourceRange.layerCount = 1;
    VkImageView view;
    if (failed(vkCreateImageView(d->handle, &view_info, 0, &view), "vkCreateImageView"))
      return;
    VkRenderingAttachmentInfo attachment;
    memset(&attachment, 0, sizeof(attachment));
    attachment.sType = VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO;
    attachment.imageView = view;
    attachment.imageLayout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
    attachment.loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR;
    attachment.storeOp = VK_ATTACHMENT_STORE_OP_STORE;
    attachment.clearValue.color = value;
    VkRenderingInfo info;
    memset(&info, 0, sizeof(info));
    info.sType = VK_STRUCTURE_TYPE_RENDERING_INFO;
    info.renderArea.offset.x = x;
    info.renderArea.offset.y = y;
    info.renderArea.extent.width = (uint32_t)width;
    info.renderArea.extent.height = (uint32_t)height;
    info.layerCount = 1;
    info.colorAttachmentCount = 1;
    info.pColorAttachments = &attachment;
    vkCmdBeginRendering(d->command, &info);
    vkCmdEndRendering(d->command);
    vkDestroyImageView(d->handle, view, 0);
  } else {
    VkClearDepthStencilValue value;
    value.depth = (float)depth_value;
    value.stencil = (uint32_t)stencil_value;
    vkCmdClearDepthStencilImage(d->command, t->handle,
                                VK_IMAGE_LAYOUT_GENERAL, &value, 1, &range);
  }
}

void mwg_vk_copy_buffer_to_texture(int64_t handle, int64_t buffer,
                                   int32_t buffer_offset, int32_t bytes_per_row,
                                   int32_t rows_per_image, int64_t texture,
                                   int32_t mip, int32_t x, int32_t y, int32_t z,
                                   int32_t width, int32_t height, int32_t depth) {
  Device *d = RECORD(Device);
  Buffer *b = AT(Buffer, buffer);
  Texture *t = AT(Texture, texture);
  if (!d || !b || !t || !d->recording) return;
  VkBufferImageCopy copy;
  memset(&copy, 0, sizeof(copy));
  copy.bufferOffset = (VkDeviceSize)buffer_offset;
  copy.bufferRowLength = (uint32_t)bytes_per_row;
  copy.bufferImageHeight = (uint32_t)rows_per_image;
  copy.imageSubresource.aspectMask = has_depth(t->format)
                                         ? VK_IMAGE_ASPECT_DEPTH_BIT
                                         : VK_IMAGE_ASPECT_COLOR_BIT;
  if (has_stencil(t->format)) copy.imageSubresource.aspectMask |= VK_IMAGE_ASPECT_STENCIL_BIT;
  copy.imageSubresource.mipLevel = (uint32_t)mip;
  copy.imageSubresource.baseArrayLayer = (uint32_t)z;
  copy.imageSubresource.layerCount = (uint32_t)(depth > 0 ? depth : 1);
  copy.imageOffset.x = x;
  copy.imageOffset.y = y;
  copy.imageOffset.z = 0;
  copy.imageExtent.width = (uint32_t)width;
  copy.imageExtent.height = (uint32_t)height;
  copy.imageExtent.depth = 1;
  vkCmdCopyBufferToImage(d->command, b->handle, t->handle,
                         VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &copy);
}

void mwg_vk_copy_texture_to_buffer(int64_t handle, int64_t texture, int32_t mip,
                                   int32_t x, int32_t y, int32_t z, int32_t width,
                                   int32_t height, int32_t depth, int64_t buffer,
                                   int32_t buffer_offset, int32_t bytes_per_row,
                                   int32_t rows_per_image) {
  Device *d = RECORD(Device);
  Texture *t = AT(Texture, texture);
  Buffer *b = AT(Buffer, buffer);
  if (!d || !t || !b || !d->recording) return;
  VkBufferImageCopy copy;
  memset(&copy, 0, sizeof(copy));
  copy.bufferOffset = (VkDeviceSize)buffer_offset;
  copy.bufferRowLength = (uint32_t)bytes_per_row;
  copy.bufferImageHeight = (uint32_t)rows_per_image;
  copy.imageSubresource.aspectMask = has_depth(t->format)
                                         ? VK_IMAGE_ASPECT_DEPTH_BIT
                                         : VK_IMAGE_ASPECT_COLOR_BIT;
  if (has_stencil(t->format)) copy.imageSubresource.aspectMask |= VK_IMAGE_ASPECT_STENCIL_BIT;
  copy.imageSubresource.mipLevel = (uint32_t)mip;
  copy.imageSubresource.baseArrayLayer = (uint32_t)z;
  copy.imageSubresource.layerCount = (uint32_t)(depth > 0 ? depth : 1);
  copy.imageOffset.x = x;
  copy.imageOffset.y = y;
  copy.imageOffset.z = 0;
  copy.imageExtent.width = (uint32_t)width;
  copy.imageExtent.height = (uint32_t)height;
  copy.imageExtent.depth = 1;
  vkCmdCopyImageToBuffer(d->command, t->handle,
                         VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, b->handle, 1,
                         &copy);
}

void mwg_vk_copy_texture(int64_t handle, int64_t source, int32_t source_mip,
                         int32_t sx, int32_t sy, int32_t sz, int64_t destination,
                         int32_t destination_mip, int32_t dx, int32_t dy,
                         int32_t dz, int32_t width, int32_t height,
                         int32_t depth) {
  Device *d = RECORD(Device);
  Texture *s = AT(Texture, source);
  Texture *t = AT(Texture, destination);
  if (!d || !s || !t || !d->recording) return;
  VkImageCopy copy;
  memset(&copy, 0, sizeof(copy));
  copy.srcSubresource.aspectMask = has_depth(s->format)
                                       ? VK_IMAGE_ASPECT_DEPTH_BIT
                                       : VK_IMAGE_ASPECT_COLOR_BIT;
  copy.srcSubresource.mipLevel = (uint32_t)source_mip;
  copy.srcSubresource.baseArrayLayer = (uint32_t)sz;
  copy.srcSubresource.layerCount = (uint32_t)(depth > 0 ? depth : 1);
  copy.srcOffset.x = sx;
  copy.srcOffset.y = sy;
  copy.srcOffset.z = 0;
  copy.dstSubresource.aspectMask = has_depth(t->format)
                                       ? VK_IMAGE_ASPECT_DEPTH_BIT
                                       : VK_IMAGE_ASPECT_COLOR_BIT;
  copy.dstSubresource.mipLevel = (uint32_t)destination_mip;
  copy.dstSubresource.baseArrayLayer = (uint32_t)dz;
  copy.dstSubresource.layerCount = (uint32_t)(depth > 0 ? depth : 1);
  copy.dstOffset.x = dx;
  copy.dstOffset.y = dy;
  copy.dstOffset.z = 0;
  copy.extent.width = (uint32_t)width;
  copy.extent.height = (uint32_t)height;
  copy.extent.depth = (uint32_t)(depth > 0 ? depth : 1);
  vkCmdCopyImage(d->command, s->handle, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                 t->handle, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &copy);
}

void mwg_vk_barrier_memory(int64_t handle) {
  Device *d = RECORD(Device);
  if (!d || !d->recording) return;
  VkMemoryBarrier barrier;
  memset(&barrier, 0, sizeof(barrier));
  barrier.sType = VK_STRUCTURE_TYPE_MEMORY_BARRIER;
  barrier.srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT |
                          VK_ACCESS_TRANSFER_WRITE_BIT |
                          VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT |
                          VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT;
  barrier.dstAccessMask = VK_ACCESS_SHADER_READ_BIT | VK_ACCESS_SHADER_WRITE_BIT |
                          VK_ACCESS_TRANSFER_READ_BIT | VK_ACCESS_TRANSFER_WRITE_BIT |
                          VK_ACCESS_INDIRECT_COMMAND_READ_BIT |
                          VK_ACCESS_HOST_READ_BIT;
  vkCmdPipelineBarrier(d->command,
                       VK_PIPELINE_STAGE_ALL_COMMANDS_BIT,
                       VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, 0, 1, &barrier, 0, 0,
                       0, 0);
}

// --- read-back -----------------------------------------------------------
//
// Reading or writing a whole subresource is a staging copy on the same queue.
// The barrier before and after it is the one the layer above would have
// recorded; taking the layout it believes the image is in keeps this side from
// keeping a second copy of that state.

static int use_of_layout(int32_t layout) {
  switch (layout) {
    case 1: return 2;
    case 2: return 3;
    case 5: return 4;
    case 6: return 5;
    default: return 0;
  }
}

static int run_aux(Device *d) {
  VkCommandBufferBeginInfo begin;
  memset(&begin, 0, sizeof(begin));
  begin.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
  begin.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
  if (failed(vkResetCommandBuffer(d->aux, 0), "vkResetCommandBuffer") ||
      failed(vkBeginCommandBuffer(d->aux, &begin), "vkBeginCommandBuffer"))
    return 0;
  return 1;
}

static int submit_aux(Device *d) {
  if (failed(vkEndCommandBuffer(d->aux), "vkEndCommandBuffer")) return 0;
  VkSubmitInfo submit;
  memset(&submit, 0, sizeof(submit));
  submit.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
  submit.commandBufferCount = 1;
  submit.pCommandBuffers = &d->aux;
  if (failed(vkQueueSubmit(d->queue, 1, &submit, VK_NULL_HANDLE),
             "vkQueueSubmit"))
    return 0;
  return failed(vkQueueWaitIdle(d->queue), "vkQueueWaitIdle") ? 0 : 1;
}

static void barrier_one(Device *d, Texture *t, int32_t mip, int32_t base_layer,
                        int32_t layers, int32_t old_layout, int32_t new_layout,
                        int32_t from_use, int32_t to_use) {
  VkImageMemoryBarrier barrier;
  memset(&barrier, 0, sizeof(barrier));
  barrier.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
  barrier.oldLayout = layout_of(old_layout);
  barrier.newLayout = layout_of(new_layout);
  barrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
  barrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
  barrier.image = t->handle;
  barrier.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
  if (has_depth(t->format)) barrier.subresourceRange.aspectMask = VK_IMAGE_ASPECT_DEPTH_BIT;
  if (has_stencil(t->format)) barrier.subresourceRange.aspectMask |= VK_IMAGE_ASPECT_STENCIL_BIT;
  barrier.subresourceRange.baseMipLevel = (uint32_t)mip;
  barrier.subresourceRange.levelCount = 1;
  barrier.subresourceRange.baseArrayLayer = (uint32_t)base_layer;
  barrier.subresourceRange.layerCount = (uint32_t)(layers > 0 ? layers : 1);
  barrier.srcAccessMask = accesses_of(from_use);
  barrier.dstAccessMask = accesses_of(to_use);
  vkCmdPipelineBarrier(d->aux, stages_of(from_use), stages_of(to_use), 0, 0, 0,
                       0, 0, 1, &barrier);
}

int32_t mwg_vk_texture_read(int64_t handle, int64_t texture, int32_t mip,
                            int32_t x, int32_t y, int32_t z, int32_t width,
                            int32_t height, int32_t depth, int32_t from_layout,
                            int32_t total, uint8_t *dst) {
  Device *d = RECORD(Device);
  Texture *t = AT(Texture, texture);
  if (!d || !t || total <= 0) return 0;
  vkQueueWaitIdle(d->queue);
  int64_t staging = mwg_vk_buffer_create(handle, total, 12, 0);
  if (!staging) return 0;
  if (!run_aux(d)) {
    mwg_vk_buffer_destroy(staging);
    return 0;
  }
  int32_t layers = depth > 0 ? depth : 1;
  barrier_one(d, t, mip, z, layers, from_layout, 3, use_of_layout(from_layout),
              1);
  VkBufferImageCopy copy;
  memset(&copy, 0, sizeof(copy));
  copy.bufferOffset = 0;
  copy.bufferRowLength = 0;
  copy.bufferImageHeight = 0;
  copy.imageSubresource.aspectMask = has_depth(t->format)
                                         ? VK_IMAGE_ASPECT_DEPTH_BIT
                                         : VK_IMAGE_ASPECT_COLOR_BIT;
  if (has_stencil(t->format)) copy.imageSubresource.aspectMask |= VK_IMAGE_ASPECT_STENCIL_BIT;
  copy.imageSubresource.mipLevel = (uint32_t)mip;
  copy.imageSubresource.baseArrayLayer = (uint32_t)z;
  copy.imageSubresource.layerCount = (uint32_t)layers;
  copy.imageOffset.x = x;
  copy.imageOffset.y = y;
  copy.imageOffset.z = 0;
  copy.imageExtent.width = (uint32_t)width;
  copy.imageExtent.height = (uint32_t)height;
  copy.imageExtent.depth = 1;
  Buffer *b = AT(Buffer, staging);
  if (!b) {
    mwg_vk_buffer_destroy(staging);
    return 0;
  }
  for (int32_t layer = 0; layer < layers; layer++) {
    copy.imageSubresource.baseArrayLayer = (uint32_t)(z + layer);
    copy.bufferOffset = (VkDeviceSize)((int64_t)layer * (total / layers));
    vkCmdCopyImageToBuffer(d->aux, t->handle,
                           VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, b->handle, 1,
                           &copy);
  }
  // The image stays in `transfer source`: the caller records that as its
  // layout, and the next barrier tells the driver the contents matter.
  int ok = submit_aux(d);
  if (ok) memcpy(dst, b->mapped, (size_t)total);
  mwg_vk_buffer_destroy(staging);
  return ok;
}

int32_t mwg_vk_texture_write(int64_t handle, int64_t texture, int32_t mip,
                             int32_t x, int32_t y, int32_t z, int32_t width,
                             int32_t height, int32_t depth, int32_t to_layout,
                             int32_t total, const uint8_t *src) {
  Device *d = RECORD(Device);
  Texture *t = AT(Texture, texture);
  if (!d || !t || total <= 0) return 0;
  vkQueueWaitIdle(d->queue);
  int64_t staging = mwg_vk_buffer_create(handle, total, 12, 0);
  if (!staging) return 0;
  Buffer *b = AT(Buffer, staging);
  if (!b) {
    mwg_vk_buffer_destroy(staging);
    return 0;
  }
  memcpy(b->mapped, src, (size_t)total);
  if (!run_aux(d)) {
    mwg_vk_buffer_destroy(staging);
    return 0;
  }
  int32_t layers = depth > 0 ? depth : 1;
  barrier_one(d, t, mip, z, layers, to_layout, 4, use_of_layout(to_layout), 1);
  VkBufferImageCopy copy;
  memset(&copy, 0, sizeof(copy));
  copy.bufferRowLength = 0;
  copy.bufferImageHeight = 0;
  copy.imageSubresource.aspectMask = has_depth(t->format)
                                         ? VK_IMAGE_ASPECT_DEPTH_BIT
                                         : VK_IMAGE_ASPECT_COLOR_BIT;
  if (has_stencil(t->format)) copy.imageSubresource.aspectMask |= VK_IMAGE_ASPECT_STENCIL_BIT;
  copy.imageSubresource.mipLevel = (uint32_t)mip;
  copy.imageSubresource.layerCount = 1;
  copy.imageOffset.x = x;
  copy.imageOffset.y = y;
  copy.imageOffset.z = 0;
  copy.imageExtent.width = (uint32_t)width;
  copy.imageExtent.height = (uint32_t)height;
  copy.imageExtent.depth = 1;
  for (int32_t layer = 0; layer < layers; layer++) {
    copy.imageSubresource.baseArrayLayer = (uint32_t)(z + layer);
    copy.bufferOffset = (VkDeviceSize)((int64_t)layer * (total / layers));
    vkCmdCopyBufferToImage(d->aux, b->handle, t->handle,
                           VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &copy);
  }
  int ok = submit_aux(d);
  mwg_vk_buffer_destroy(staging);
  return ok;
}

#else  // MWG_VULKAN
//
// No Vulkan headers on this machine. The entry points still exist, so a program
// that links against this backend starts, and every one of them reports that
// the loader cannot be reached.

#include <string.h>

static const char g_no_vulkan[] =
    "this build has no Vulkan headers, so the loader cannot be reached; "
    "install the Vulkan development files to build the backend";

int64_t mwg_vk_error_copy(uint8_t *dst, int32_t capacity) {
  size_t n = strlen(g_no_vulkan);
  if (capacity <= 0) return 0;
  if ((int32_t)n > capacity - 1) n = (size_t)(capacity - 1);
  memcpy(dst, g_no_vulkan, n);
  dst[n] = 0;
  return (int64_t)n;
}

int64_t mwg_vk_available(void) {
  return 0;
}

int64_t mwg_vk_instance_create(void) {
  return 0;
}

void mwg_vk_instance_destroy(int64_t instance) {
  (void)instance;
}

int32_t mwg_vk_device_count(int64_t instance) {
  (void)instance; return 0;
}

int64_t mwg_vk_physical_info(int64_t instance, int32_t index, uint8_t * dst) {
  (void)instance; (void)index; (void)dst; return 0;
}

int64_t mwg_vk_device_create(int64_t instance, int32_t index, int64_t * report) {
  (void)instance; (void)index; (void)report; return 0;
}

void mwg_vk_device_destroy(int64_t device) {
  (void)device;
}

int64_t mwg_vk_device_wait(int64_t device) {
  (void)device; return 0;
}

int64_t mwg_vk_format(const uint8_t * name, int32_t length) {
  (void)name; (void)length; return 0;
}

int64_t mwg_vk_buffer_create(int64_t device, int32_t size, int32_t usage, int32_t zero) {
  (void)device; (void)size; (void)usage; (void)zero; return 0;
}

void mwg_vk_buffer_destroy(int64_t buffer) {
  (void)buffer;
}

int32_t mwg_vk_buffer_write(int64_t buffer, int32_t offset, const uint8_t * source, int32_t length) {
  (void)buffer; (void)offset; (void)source; (void)length; return 0;
}

int32_t mwg_vk_buffer_read(int64_t buffer, int32_t offset, uint8_t * dst, int32_t length) {
  (void)buffer; (void)offset; (void)dst; (void)length; return 0;
}

int64_t mwg_vk_texture_create(int64_t device, int32_t width, int32_t height, int32_t depth, int32_t layers, int32_t mips, int32_t samples, int32_t dimension, int64_t format, int32_t usage) {
  (void)device; (void)width; (void)height; (void)depth; (void)layers; (void)mips; (void)samples; (void)dimension; (void)format; (void)usage; return 0;
}

void mwg_vk_texture_destroy(int64_t texture) {
  (void)texture;
}

int64_t mwg_vk_view_create(int64_t device, int64_t texture, int64_t format, int32_t dimension, int32_t aspect, int32_t base_mip, int32_t mip_count, int32_t base_layer, int32_t layer_count) {
  (void)device; (void)texture; (void)format; (void)dimension; (void)aspect; (void)base_mip; (void)mip_count; (void)base_layer; (void)layer_count; return 0;
}

void mwg_vk_view_destroy(int64_t view) {
  (void)view;
}

int64_t mwg_vk_sampler_create(int64_t device, int32_t mag, int32_t min, int32_t mip, int32_t address_u, int32_t address_v, int32_t address_w, double lod_min, double lod_max, int32_t compare_enabled, int32_t compare, double anisotropy) {
  (void)device; (void)mag; (void)min; (void)mip; (void)address_u; (void)address_v; (void)address_w; (void)lod_min; (void)lod_max; (void)compare_enabled; (void)compare; (void)anisotropy; return 0;
}

void mwg_vk_sampler_destroy(int64_t sampler) {
  (void)sampler;
}

int64_t mwg_vk_shader_create(int64_t device, const uint8_t * words, int32_t length) {
  (void)device; (void)words; (void)length; return 0;
}

void mwg_vk_shader_destroy(int64_t shader) {
  (void)shader;
}

int64_t mwg_vk_set_layout_create(int64_t device, int32_t * entries, int32_t count) {
  (void)device; (void)entries; (void)count; return 0;
}

void mwg_vk_set_layout_destroy(int64_t layout) {
  (void)layout;
}

int64_t mwg_vk_pipeline_layout_create(int64_t device, int64_t * layouts, int32_t count) {
  (void)device; (void)layouts; (void)count; return 0;
}

void mwg_vk_pipeline_layout_destroy(int64_t layout) {
  (void)layout;
}

int64_t mwg_vk_set_create(int64_t device, int64_t layout) {
  (void)device; (void)layout; return 0;
}

void mwg_vk_set_destroy(int64_t set) {
  (void)set;
}

int32_t mwg_vk_set_buffer(int64_t set, int32_t binding, int64_t buffer, int32_t offset, int32_t size, int32_t kind) {
  (void)set; (void)binding; (void)buffer; (void)offset; (void)size; (void)kind; return 0;
}

int32_t mwg_vk_set_sampler(int64_t set, int32_t binding, int64_t sampler) {
  (void)set; (void)binding; (void)sampler; return 0;
}

int32_t mwg_vk_set_texture(int64_t set, int32_t binding, int64_t view, int32_t kind) {
  (void)set; (void)binding; (void)view; (void)kind; return 0;
}

int64_t mwg_vk_render_pipeline_create(int64_t device, int64_t layout, int64_t vertex, const uint8_t * vertex_entry, int32_t vertex_length, int64_t fragment, const uint8_t * fragment_entry, int32_t fragment_length, int32_t * stream, int32_t count, int32_t bias_constant, double bias_slope, double bias_clamp) {
  (void)device; (void)layout; (void)vertex; (void)vertex_entry; (void)vertex_length; (void)fragment; (void)fragment_entry; (void)fragment_length; (void)stream; (void)count; (void)bias_constant; (void)bias_slope; (void)bias_clamp; return 0;
}

int64_t mwg_vk_compute_pipeline_create(int64_t device, int64_t layout, int64_t compute, const uint8_t * entry, int32_t length) {
  (void)device; (void)layout; (void)compute; (void)entry; (void)length; return 0;
}

void mwg_vk_pipeline_destroy(int64_t pipeline) {
  (void)pipeline;
}

int64_t mwg_vk_queries_create(int64_t device, int32_t kind, int32_t count) {
  (void)device; (void)kind; (void)count; return 0;
}

void mwg_vk_queries_destroy(int64_t queries) {
  (void)queries;
}

int32_t mwg_vk_record_begin(int64_t device) {
  (void)device; return 0;
}

int32_t mwg_vk_record_submit(int64_t device) {
  (void)device; return 0;
}

void mwg_vk_record_abandon(int64_t device) {
  (void)device;
}

int32_t mwg_vk_begin_render(int64_t device, int32_t width, int32_t height, int32_t colors, int64_t * views, int64_t * formats, int32_t * loads, int32_t * stores, double * clears, int64_t depth_view, int64_t depth_format, int32_t depth_load, int32_t depth_store, double depth_clear, int32_t stencil_clear, int32_t depth_read_only) {
  (void)device; (void)width; (void)height; (void)colors; (void)views; (void)formats; (void)loads; (void)stores; (void)clears; (void)depth_view; (void)depth_format; (void)depth_load; (void)depth_store; (void)depth_clear; (void)stencil_clear; (void)depth_read_only; return 0;
}

void mwg_vk_end_render(int64_t device) {
  (void)device;
}

void mwg_vk_begin_compute(int64_t device) {
  (void)device;
}

void mwg_vk_end_compute(int64_t device) {
  (void)device;
}

void mwg_vk_bind_pipeline(int64_t device, int64_t pipeline) {
  (void)device; (void)pipeline;
}

void mwg_vk_bind_set(int64_t device, int32_t index, int64_t set, int32_t * offsets, int32_t count, int32_t compute) {
  (void)device; (void)index; (void)set; (void)offsets; (void)count; (void)compute;
}

void mwg_vk_push_constants(int64_t device, int32_t offset, const uint8_t * data, int32_t length, int32_t compute) {
  (void)device; (void)offset; (void)data; (void)length; (void)compute;
}

void mwg_vk_vertex_buffer(int64_t device, int32_t slot, int64_t buffer, int32_t offset) {
  (void)device; (void)slot; (void)buffer; (void)offset;
}

void mwg_vk_index_buffer(int64_t device, int64_t buffer, int32_t offset, int32_t format) {
  (void)device; (void)buffer; (void)offset; (void)format;
}

void mwg_vk_draw(int64_t device, int32_t vertices, int32_t instances, int32_t first_vertex, int32_t first_instance) {
  (void)device; (void)vertices; (void)instances; (void)first_vertex; (void)first_instance;
}

void mwg_vk_draw_indexed(int64_t device, int32_t indices, int32_t instances, int32_t first_index, int32_t base_vertex, int32_t first_instance) {
  (void)device; (void)indices; (void)instances; (void)first_index; (void)base_vertex; (void)first_instance;
}

void mwg_vk_draw_indirect(int64_t device, int64_t buffer, int32_t offset, int32_t indexed) {
  (void)device; (void)buffer; (void)offset; (void)indexed;
}

void mwg_vk_dispatch(int64_t device, int32_t x, int32_t y, int32_t z) {
  (void)device; (void)x; (void)y; (void)z;
}

void mwg_vk_dispatch_indirect(int64_t device, int64_t buffer, int32_t offset) {
  (void)device; (void)buffer; (void)offset;
}

void mwg_vk_viewport(int64_t device, double x, double y, double width, double height, double min_depth, double max_depth) {
  (void)device; (void)x; (void)y; (void)width; (void)height; (void)min_depth; (void)max_depth;
}

void mwg_vk_scissor(int64_t device, int32_t x, int32_t y, int32_t width, int32_t height) {
  (void)device; (void)x; (void)y; (void)width; (void)height;
}

void mwg_vk_blend_constants(int64_t device, double r, double g, double b, double a) {
  (void)device; (void)r; (void)g; (void)b; (void)a;
}

void mwg_vk_stencil_reference(int64_t device, int32_t reference) {
  (void)device; (void)reference;
}

void mwg_vk_begin_query(int64_t device, int64_t queries, int32_t index) {
  (void)device; (void)queries; (void)index;
}

void mwg_vk_end_query(int64_t device, int64_t queries, int32_t index) {
  (void)device; (void)queries; (void)index;
}

void mwg_vk_write_timestamp(int64_t device, int64_t queries, int32_t index) {
  (void)device; (void)queries; (void)index;
}

void mwg_vk_resolve_queries(int64_t device, int64_t queries, int32_t first, int32_t count, int64_t buffer, int32_t offset) {
  (void)device; (void)queries; (void)first; (void)count; (void)buffer; (void)offset;
}

void mwg_vk_barrier(int64_t device, int64_t texture, int32_t mip, int32_t base_layer, int32_t layer_count, int32_t old_layout, int32_t new_layout, int32_t from_use, int32_t to_use) {
  (void)device; (void)texture; (void)mip; (void)base_layer; (void)layer_count; (void)old_layout; (void)new_layout; (void)from_use; (void)to_use;
}

void mwg_vk_copy_buffer(int64_t device, int64_t source, int32_t source_offset, int64_t destination, int32_t destination_offset, int32_t size) {
  (void)device; (void)source; (void)source_offset; (void)destination; (void)destination_offset; (void)size;
}

void mwg_vk_fill_buffer(int64_t device, int64_t buffer, int32_t offset, int32_t size, int32_t value) {
  (void)device; (void)buffer; (void)offset; (void)size; (void)value;
}

void mwg_vk_clear_texture(int64_t device, int64_t texture, int32_t mip, int32_t x, int32_t y, int32_t z, int32_t width, int32_t height, int32_t depth, int32_t is_float, double * color, int32_t * uint_color, double depth_value, int32_t stencil_value, int32_t stencil_only) {
  (void)device; (void)texture; (void)mip; (void)x; (void)y; (void)z; (void)width; (void)height; (void)depth; (void)is_float; (void)color; (void)uint_color; (void)depth_value; (void)stencil_value; (void)stencil_only;
}

void mwg_vk_copy_buffer_to_texture(int64_t device, int64_t buffer, int32_t buffer_offset, int32_t bytes_per_row, int32_t rows_per_image, int64_t texture, int32_t mip, int32_t x, int32_t y, int32_t z, int32_t width, int32_t height, int32_t depth) {
  (void)device; (void)buffer; (void)buffer_offset; (void)bytes_per_row; (void)rows_per_image; (void)texture; (void)mip; (void)x; (void)y; (void)z; (void)width; (void)height; (void)depth;
}

void mwg_vk_copy_texture_to_buffer(int64_t device, int64_t texture, int32_t mip, int32_t x, int32_t y, int32_t z, int32_t width, int32_t height, int32_t depth, int64_t buffer, int32_t buffer_offset, int32_t bytes_per_row, int32_t rows_per_image) {
  (void)device; (void)texture; (void)mip; (void)x; (void)y; (void)z; (void)width; (void)height; (void)depth; (void)buffer; (void)buffer_offset; (void)bytes_per_row; (void)rows_per_image;
}

void mwg_vk_copy_texture(int64_t device, int64_t source, int32_t source_mip, int32_t x, int32_t y, int32_t z, int64_t destination, int32_t destination_mip, int32_t destination_x, int32_t destination_y, int32_t destination_z, int32_t width, int32_t height, int32_t depth) {
  (void)device; (void)source; (void)source_mip; (void)x; (void)y; (void)z; (void)destination; (void)destination_mip; (void)destination_x; (void)destination_y; (void)destination_z; (void)width; (void)height; (void)depth;
}

int32_t mwg_vk_texture_read(int64_t device, int64_t texture, int32_t mip, int32_t x, int32_t y, int32_t z, int32_t width, int32_t height, int32_t depth, int32_t layout, int32_t total, uint8_t * dst) {
  (void)device; (void)texture; (void)mip; (void)x; (void)y; (void)z; (void)width; (void)height; (void)depth; (void)layout; (void)total; (void)dst; return 0;
}

int32_t mwg_vk_texture_write(int64_t device, int64_t texture, int32_t mip, int32_t x, int32_t y, int32_t z, int32_t width, int32_t height, int32_t depth, int32_t layout, int32_t total, const uint8_t * source) {
  (void)device; (void)texture; (void)mip; (void)x; (void)y; (void)z; (void)width; (void)height; (void)depth; (void)layout; (void)total; (void)source; return 0;
}

void mwg_vk_barrier_memory(int64_t device) {
  (void)device;
}

#endif  // MWG_VULKAN
