# Copyright (c) CloudBees, Inc.

# CloudBees.io currently only supports root user to operate with the Workspace

FROM alpine:3.22.0

ENV TF_VERSION=1.9.8 \
    KUBECTL_VERSION=1.31.2 \
    VELERO_VERSION=1.16.1 \
    EKSCTL_VERSION=0.210.0 \
    ARCH=amd64

RUN apk add --update --no-cache \
    bash \
    unzip \
    curl \
    git \
    make \
    aws-cli \
    yq \
    jq

RUN curl -sLO https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_${ARCH}.zip && \
    unzip terraform_${TF_VERSION}_linux_${ARCH}.zip && \
    mv terraform /usr/bin/terraform && \
    chmod +x /usr/bin/terraform && \
    rm terraform_${TF_VERSION}_linux_${ARCH}.zip

RUN curl -sLO https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl && \
    mv kubectl /usr/bin/kubectl && \
    chmod +x /usr/bin/kubectl

RUN curl -sLO https://github.com/vmware-tanzu/velero/releases/download/v${VELERO_VERSION}/velero-v${VELERO_VERSION}-linux-${ARCH}.tar.gz && \
    tar zxvf velero-v${VELERO_VERSION}-linux-${ARCH}.tar.gz && \
    mv velero-v${VELERO_VERSION}-linux-${ARCH}/velero /usr/bin/velero && \
    chmod +x /usr/bin/velero && \
    rm velero-v${VELERO_VERSION}-linux-${ARCH}.tar.gz

RUN curl -sLO "https://github.com/eksctl-io/eksctl/releases/download/v${EKSCTL_VERSION}/eksctl_Linux_${ARCH}.tar.gz" && \
    tar -xzf eksctl_Linux_${ARCH}.tar.gz -C /usr/bin && \
    chmod +x /usr/bin/eksctl && \
    rm eksctl_Linux_${ARCH}.tar.gz
