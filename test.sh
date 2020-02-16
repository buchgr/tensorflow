#!/bin/bash

set -ex

export ACTION_PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export LD_LIBRARY_PATH="/usr/local/cuda/lib64:/usr/local/cuda/extras/CUPTI/lib64"
export PYTHON_BIN_PATH="/usr/bin/python3"
export TF2_BEHAVIOR=1

CACHE_SILO_VAL="gpu-ubuntu-16-buchgr-test"

# Do not run configure.py when doing remote build & test:
# Most things we set with configure.py are not used in a remote build setting,
# as the build will be defined by pre-configured build files that are checked
# in.
# TODO(klimek): Allow using the right set of bazel flags without the need to
# run configure.py; currently we need to carefully copy them, which is brittle.

# TODO(klimek): Remove once we don't try to read it while setting up the remote
# config for cuda (we currently don't use it, as it's only used when compiling
# with clang, but we still require it to be set anyway).
export TF_CUDA_COMPUTE_CAPABILITIES=6.0

# Get the default test targets for bazel.
source tensorflow/tools/ci_build/build_scripts/PRESUBMIT_BUILD_TARGETS.sh

# TODO(klimek):
# Stop using action_env for things that are only needed during setup - we're
# artificially poisoning the cache.

bazel \
  test \
  --config=rbe \
  --python_path="${PYTHON_BIN_PATH}" \
  --action_env=PATH="${ACTION_PATH}" \
  --action_env=TF2_BEHAVIOR="${TF2_BEHAVIOR}" \
  --action_env=PYTHON_BIN_PATH="${PYTHON_BIN_PATH}" \
  --action_env=REMOTE_GPU_TESTING=1 \
  --action_env=TF_CUDA_COMPUTE_CAPABILITIES="${TF_CUDA_COMPUTE_CAPABILITIES}" \
  --action_env=TF_CUDA_CONFIG_REPO="@ubuntu16.04-py3-gcc7_manylinux2010-cuda10.0-cudnn7-tensorrt5.1_config_cuda//" \
  --action_env=TF_CUDA_VERSION=10 \
  --action_env=TF_CUDNN_VERSION=7 \
  --action_env=TF_NEED_TENSORRT=1 \
  --action_env=TF_TENSORRT_CONFIG_REPO="@ubuntu16.04-py3-gcc7_manylinux2010-cuda10.0-cudnn7-tensorrt5.1_config_tensorrt//" \
  --action_env=TF_NEED_CUDA=1 \
  --action_env=TF_PYTHON_CONFIG_REPO="@ubuntu16.04-py3-gcc7_manylinux2010-cuda10.0-cudnn7-tensorrt5.1_config_python//" \
  --action_env=TF_NCCL_CONFIG_REPO="@ubuntu16.04-py3-gcc7_manylinux2010-cuda10.0-cudnn7-tensorrt5.1_config_nccl//" \
  -c opt \
  --copt="-w" \
  --copt=-mavx \
  --linkopt=-lrt \
  --linkopt=-lm \
  --crosstool_top=@ubuntu16.04-py3-gcc7_manylinux2010-cuda10.0-cudnn7-tensorrt5.1_config_cuda//crosstool:toolchain \
  --define=with_default_optimizations=true \
  --define=framework_shared_object=true \
  --define=with_xla_support=true \
  --define=using_cuda_nvcc=true \
  --define=use_fast_cpp_protos=true \
  --define=allow_oversize_protos=true \
  --define=grpc_no_ares=true \
  --distinct_host_configuration=false \
  --remote_default_exec_properties=build="${CACHE_SILO_VAL}" \
  --extra_execution_platforms=@org_tensorflow//third_party/toolchains:rbe_cuda10.0-cudnn7-ubuntu16.04-manylinux2010 \
  --extra_toolchains=@ubuntu16.04-py3-gcc7_manylinux2010-cuda10.0-cudnn7-tensorrt5.1_config_cuda//crosstool:toolchain-linux-x86_64 \
  --java_toolchain=@bazel_tools//tools/jdk:toolchain_hostjdk8 \
  --javabase=@bazel_toolchains//configs/ubuntu16_04_clang/1.0:jdk8 \
  --local_test_jobs=4 \
  --platforms=@org_tensorflow//third_party/toolchains:rbe_cuda10.0-cudnn7-ubuntu16.04-manylinux2010 \
  --host_platform=@org_tensorflow//third_party/toolchains:rbe_cuda10.0-cudnn7-ubuntu16.04-manylinux2010 \
  --remote_timeout=3600 \
  --test_env=LD_LIBRARY_PATH \
  --test_tag_filters=gpu,-no_gpu,-nogpu,-benchmark-test,-no_oss,-oss_serial,-v1only,-no_gpu_presubmit \
  --remote_instance_name=projects/tensorflow-testing/instances/default_instance \
  --experimental_repo_remote_exec \
  -- \
  ${DEFAULT_BAZEL_TARGETS} -//tensorflow/lite/...