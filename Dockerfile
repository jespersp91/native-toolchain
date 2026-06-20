FROM ubuntu

RUN apt update && apt install -y curl xz-utils git sudo
# add user ubuntu and add user to sudoers 
RUN echo "ubuntu ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
USER ubuntu

#install nix
RUN curl -L https://nixos.org/nix/install | sh
# extra-experimental-features nix-command flakes
RUN mkdir -p ~/.config/nix/
RUN echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
RUN echo ". ~/.nix-profile/etc/profile.d/nix.sh" >> ~/.bashrc
ENV USER ubuntu
RUN  . ~/.nix-profile/etc/profile.d/nix.sh && nix profile install nixpkgs#python3 nixpkgs#gnumake42  nixpkgs#cmake nixpkgs#hexdump
RUN  . ~/.nix-profile/etc/profile.d/nix.sh && nix develop github:jespersp91/native-toolchain -c true
RUN git clone 
CMD  . ~/.nix-profile/etc/profile.d/nix.sh && nix develop github:jespersp91/native-toolchain 
