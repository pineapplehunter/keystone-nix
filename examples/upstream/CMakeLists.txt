cmake_minimum_required(VERSION 3.10)
project(keystone_samples C CXX)

include(GNUInstallDirs)

set(sdk "$ENV{KEYSTONE_SDK_DIR}")
link_directories("${sdk}/lib")

add_executable(hello-native hello-native/eapp/eapp_native.c)
target_include_directories(hello-native PRIVATE "${sdk}/include/app" "${sdk}/include/edge")
target_link_libraries(hello-native PRIVATE "-nostdlib" "-static" keystone-eapp keystone-edge)

add_executable(hello-native-runner hello-native/host/host_native.cpp)
target_compile_features(hello-native-runner PRIVATE cxx_std_11)
target_include_directories(hello-native-runner PRIVATE "${sdk}/include/host" "${sdk}/include/edge")
target_link_libraries(hello-native-runner PRIVATE keystone-host keystone-edge)

add_executable(attestor attestation/eapp/attestor.c)
target_include_directories(attestor PRIVATE "${sdk}/include" "${sdk}/include/app" "${sdk}/include/edge")
target_link_libraries(attestor PRIVATE "-nostdlib" "-static" keystone-eapp keystone-edge)

add_executable(attestor-runner
  attestation/host/attestor-runner.cpp
  attestation/host/host.cpp
  attestation/host/verifier.cpp
)
target_compile_features(attestor-runner PRIVATE cxx_std_17)
target_include_directories(attestor-runner PRIVATE attestation/host "${sdk}/include")
target_link_libraries(attestor-runner PRIVATE keystone-host keystone-edge keystone-verifier)

install(TARGETS hello-native attestor DESTINATION ${CMAKE_INSTALL_DATADIR}/keystone)
install(TARGETS hello-native-runner attestor-runner DESTINATION ${CMAKE_INSTALL_LIBEXECDIR})
