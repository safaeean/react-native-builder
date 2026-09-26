FROM eclipse-temurin:17-jdk-jammy

LABEL description="Build image for producing Android outputs (APK/AAB) from React Native projects via GitLab CI"

ENV DEBIAN_FRONTEND=noninteractive \
    ANDROID_HOME=/opt/android-sdk \
    ANDROID_SDK_ROOT=/opt/android-sdk \
    NODE_VERSION=22 \
    GRADLE_OPTS="-Dorg.gradle.daemon=false" \
    LANG=en_US.UTF-8

ARG ANDROID_CMDLINE_TOOLS_VERSION=11076708
ARG ANDROID_PLATFORM=android-34
ARG ANDROID_BUILD_TOOLS=34.0.0

# --- Base packages ---
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        unzip \
        git \
        wget \
        openssh-client \
        python3 \
        ca-certificates \
        locales \
        ruby-full \
        build-essential \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# --- Node.js ---
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g yarn \
    && rm -rf /var/lib/apt/lists/*

# --- Fastlane (optional, useful for publishing/signing automation) ---
RUN gem install bundler fastlane -N

# --- Android SDK (command-line tools only) ---
RUN mkdir -p ${ANDROID_HOME}/cmdline-tools \
    && cd /tmp \
    && wget -q https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip -O cmdline-tools.zip \
    && unzip -q cmdline-tools.zip -d ${ANDROID_HOME}/cmdline-tools \
    && mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest \
    && rm cmdline-tools.zip

ENV PATH=${PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/build-tools/${ANDROID_BUILD_TOOLS}

RUN yes | sdkmanager --licenses > /dev/null \
    && sdkmanager \
        "platform-tools" \
        "platforms;${ANDROID_PLATFORM}" \
        "build-tools;${ANDROID_BUILD_TOOLS}"

WORKDIR /project

CMD ["/bin/bash"]
