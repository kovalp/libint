#!/bin/sh

# this script builds a 'Trusty' env docker image used by Travis-CI for Libint project
#
# to run bash in the image: docker run -it libint-travis-debug bash -l
# see https://github.com/evaleev/libint/wiki/Travis-CI-Administration-Notes for further instructions
# N.B. relevant locations:
#   - source dir: /home/travis/build/evaleev/libint (TRAVIS_BUILD_DIR env in Travis jobs)
#   - build dir: /home/travis/_build
#   - install dir: /home/travis/_install

# this is where in the container file system Travis-CI "starts"
export TRAVIS_BUILD_TOPDIR=/home/travis/build

##############################################################
# make a script to download all prereqs and clone libint repo
setup=setup.sh
cat > $setup << END
#!/bin/sh
curl -sSL "http://apt.llvm.org/llvm-snapshot.gpg.key" | apt-key add -
echo "deb http://apt.llvm.org/trusty/ llvm-toolchain-trusty-6.0 main" | tee -a /etc/apt/sources.list > /dev/null
apt-add-repository -y "ppa:ubuntu-toolchain-r/test"
apt-add-repository -y "ppa:boost-latest/ppa"
apt-get -yq update >> ~/apt-get-update.log
apt-get -yq --no-install-suggests --no-install-recommends --force-yes install g++-5 g++-6 g++-7 g++-8 gfortran-5 gfortran-6 gfortran-7 gfortran-8 libgmp-dev libeigen3-dev libboost1.55-all-dev clang-6.0
mkdir -p ${TRAVIS_BUILD_TOPDIR}
cd ${TRAVIS_BUILD_TOPDIR}
git clone https://github.com/evaleev/libint.git ${TRAVIS_BUILD_TOPDIR}/evaleev/libint
END
chmod +x $setup

##############################################################
# make a script to build everything once in the container
build=build.sh
cat > $build << END
#!/bin/sh
cd /home/travis/_build
export BUILD_PREFIX=/home/travis/_build
export INSTALL_PREFIX=/home/travis/_install
export TRAVIS_BUILD_DIR=${TRAVIS_BUILD_TOPDIR}/evaleev/libint
./travisci_build_linux.sh
END
chmod +x $build

##############################################################
# make Dockerfile
cat > Dockerfile << END
# Travis default 'Trusty' image
FROM travisci/ci-garnet:packer-1503972846

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]

# create source, build, and install dirs
RUN mkdir -p /home/travis/_build
RUN mkdir -p /home/travis/_install

# install prereqs
ADD $setup /home/travis/_build/$setup
RUN /home/travis/_build/$setup

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# copy travis scripts
ADD travisci_build_linux.sh /home/travis/_build/travisci_build_linux.sh
ADD $build /home/travis/_build/$build
END

function clean_up {
  rm -f $setup $build Dockerfile
  exit
}

trap clean_up SIGHUP SIGINT SIGTERM

##############################################################
# build a dev image
docker build -t libint-travis-debug .

##############################################################
# extra admin tasks, uncomment as needed

##############################################################
# done
clean_up
