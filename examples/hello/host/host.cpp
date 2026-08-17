//******************************************************************************
// Copyright (c) 2018, The Regents of the University of California (Regents).
// All Rights Reserved. See LICENSE for license details.
//------------------------------------------------------------------------------
#include "edge/edge_call.h"
#include "host/keystone.h"

#include <cerrno>
#include <cstring>
#include <iostream>
#include <unistd.h>

using namespace Keystone;

namespace {
int
report_error(const char* operation, Error error) {
  std::cerr << operation << " failed with Keystone error "
            << static_cast<int>(error) << '\n';
  return 1;
}
}  // namespace

int
main(int argc, char** argv) {
  if (argc != 4) {
    std::cerr << "usage: " << argv[0] << " EAPP RUNTIME LOADER\n";
    return 2;
  }

  for (int i = 1; i < argc; ++i) {
    if (access(argv[i], R_OK) != 0) {
      std::cerr << "cannot read enclave input '" << argv[i]
                << "': " << std::strerror(errno) << '\n';
      return 1;
    }
  }

  Enclave enclave;
  Params params;

  params.setFreeMemSize(1024 * 1024);
  params.setUntrustedSize(1024 * 1024);

  Error error = enclave.init(argv[1], argv[2], argv[3], params);
  if (error != Error::Success) {
    return report_error("enclave initialization", error);
  }

  error = enclave.registerOcallDispatch(incoming_call_dispatch);
  if (error != Error::Success) {
    return report_error("OCALL registration", error);
  }
  edge_call_init_internals(
      (uintptr_t)enclave.getSharedBuffer(), enclave.getSharedBufferSize());

  uintptr_t return_value = 0;
  error = enclave.run(&return_value);
  if (error != Error::Success) {
    return report_error("enclave execution", error);
  }
  if (return_value != 0) {
    std::cerr << "enclave execution returned " << return_value << '\n';
    return 1;
  }

  return 0;
}
