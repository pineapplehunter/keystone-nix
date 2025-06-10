cmake_minimum_required(VERSION 3.10)
project(hello C CXX)

include(GNUInstallDirs)

add_executable(hello-runner host/host.cpp)
target_link_libraries(hello-runner keystone-edge keystone-host)
install(TARGETS hello-runner DESTINATION ${CMAKE_INSTALL_BINDIR})

add_executable(hello eapp/hello.c)
target_link_libraries(hello PRIVATE "-static")
install(TARGETS hello DESTINATION ${CMAKE_INSTALL_DATADIR})
