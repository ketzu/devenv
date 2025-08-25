FROM ubuntu:24.04

RUN apt update && apt upgrade -y
RUN DEBIAN_FRONTEND=noninteractive TZ=Europe/Berlin apt -y install tzdata
RUN apt -y install build-essential git git-core openssh-server pipx curl nano sudo net-tools dnsutils netcat-openbsd ca-certificates bash-completion iproute2  gcc python3-dev apt-transport-https gnupg

RUN curl -fsSL https://get.docker.com | bash -s --

# SSHD config for only pubkey authentication
COPY sshd_config /etc/ssh/sshd_config
RUN chmod 0644 /etc/ssh/sshd_config

# Passwordless root
COPY sudoers /etc/sudoers.d/50-system-init
RUN chmod 0440 /etc/sudoers.d/50-system-init

RUN mkdir /var/run/sshd && chmod 0755 /var/run/sshd

EXPOSE 22
CMD ["/usr/sbin/sshd", "-De"]

ENV CARGO_HOME="/usr/local/cargo"
ENV RUSTUP_HOME="/usr/local/rustup"
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | bash -s -- -y
ENV PATH="/usr/local/cargo/bin:/usr/local/rustup/bin:$PATH"
RUN rustup default stable

ENV UV_INSTALL_DIR="/usr/local/bin"
RUN curl -LsSf https://astral.sh/uv/install.sh | bash -s --
RUN uv python install 3.11 3.12 3.13 3.14
RUN uv tool install ruff

RUN groupadd -g 8373 -o user
RUN useradd -m -u 8373 -g 8373 -G sudo -o -s /bin/bash user
RUN usermod -aG docker user
RUN systemctl enable docker.service
RUN systemctl enable containerd.service

# Install kubectl
RUN curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
RUN chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
RUN echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
RUN chmod 644 /etc/apt/sources.list.d/kubernetes.list
RUN apt update
RUN apt install -y kubectl

RUN apt update && apt install -y fzf htop jq zsh yq fuse-overlayfs

# Install k9s
RUN wget https://github.com/derailed/k9s/releases/download/v0.50.9/k9s_linux_amd64.deb && apt install ./k9s_linux_amd64.deb && rm ./k9s_linux_amd64.deb

# Install kind
RUN curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.29.0/kind-linux-amd64
RUN chmod +x ./kind
RUN mv ./kind /usr/local/bin/kind

# install nushell
RUN curl -fsSL https://apt.fury.io/nushell/gpg.key | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/fury-nushell.gpg
RUN echo "deb https://apt.fury.io/nushell/ /" | sudo tee /etc/apt/sources.list.d/fury.list
RUN apt update && apt install nushell

# install helm
RUN curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
RUN echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
RUN apt update && apt install helm

# set additional file limits
# COPY sysctl.conf /etc/sysctl.conf
# COPY limits.conf /etc/security/limits.conf
