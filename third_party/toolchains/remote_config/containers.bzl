load("//third_party/toolchains/preconfig/generate:containers.bzl", "container_digests")

containers = {

    "ubuntu16.04" : {
        "registry" : "gcr.io",
        "repository" : "tensorflow-testing/nosla-ubuntu16.04",
        "digest" : container_digests["ubuntu16.04"],
    },

    "centos6" : {
        "registry" : "gcr.io",
        "repository" : "tensorflow-testing/nosla-centos6",
        "digest" : container_digests["centos6"],
    },

    "ubuntu16.04-manylinux2010" : {
        "registry" : "gcr.io",
        "repository" : "tensorflow-testing/nosla-ubuntu16.04-manylinux2010",
        "digest" : container_digests["ubuntu16.04-manylinux2010"],
    },

    "cuda10.0-cudnn7-ubuntu14.04" : {
        "registry" : "gcr.io",
        "repository" : "tensorflow-testing/nosla-cuda10.0-cudnn7-ubuntu14.04",
        "digest" : container_digests["cuda10.0-cudnn7-ubuntu14.04"],
    },

    "cuda10.0-cudnn7-centos6" : {
        "registry" : "gcr.io",
        "repository" : "tensorflow-testing/nosla-cuda10.0-cudnn7-centos6",
        "digest" : container_digests["cuda10.0-cudnn7-centos6"],
    },

    "cuda10.1-cudnn7-centos6" : {
        "registry" : "gcr.io",
        "repository" : "tensorflow-testing/nosla-cuda10.1-cudnn7-centos6",
        "digest" : container_digests["cuda10.1-cudnn7-centos6"],
    },

    "cuda10.0-cudnn7-ubuntu16.04-manylinux2010" : {
        "registry" : "gcr.io",
        "repository" : "tensorflow-testing/nosla-cuda10.0-cudnn7-ubuntu16.04-manylinux2010",
        "digest" : container_digests["cuda10.0-cudnn7-ubuntu16.04-manylinux2010"],
    },

    "cuda10.1-cudnn7-ubuntu16.04-manylinux2010" : {
        "registry" : "gcr.io",
        "repository" : "tensorflow-testing/nosla-cuda10.1-cudnn7-ubuntu16.04-manylinux2010",
        "digest" : container_digests["cuda10.1-cudnn7-ubuntu16.04-manylinux2010"],
    },

    "rocm-ubuntu16.04" : {
        "registry" : "gcr.io",
        "repository" : "tensorflow-testing/nosla-rocm-ubuntu16.04",
        "digest" : container_digests["rocm-ubuntu16.04"],
    },
}


