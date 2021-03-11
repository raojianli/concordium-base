pipeline {
    agent any
    environment {
        FILENAME_DEBUG = 'mobile_wallet_lib-debug.aar'
        FILENAME_RELEASE = 'mobile_wallet_lib-release.aar'
        S3_BUCKET = 's3://static-libraries.concordium.com/android'
    }
    stages {
        stage('ecr-login') {
            agent { label 'jenkins-worker' }
            steps {
                sh 'aws ecr get-login-password \
                        --region eu-west-1 \
                    | docker login \
                        --username AWS \
                        --password-stdin 192549843005.dkr.ecr.eu-west-1.amazonaws.com'
            }
        }
        stage('build') {
            agent { 
                docker {
                    label 'jenkins-worker'
                    image 'concordium/android-builder:latest' 
                    registryUrl 'https://192549843005.dkr.ecr.eu-west-1.amazonaws.com/'
                    args '-u root'
                } 
            }

            steps {
                sh '''\
                    # Move into folder
                    cd mobile_wallet

                    # Build android
                    min_ver=29
                    cargo ndk --target aarch64-linux-android --platform ${min_ver} -- build --release
                    cargo ndk --target armv7-linux-androideabi --platform ${min_ver} -- build --release
                    cargo ndk --target i686-linux-android --platform ${min_ver} -- build --release
                    cargo ndk --target x86_64-linux-android --platform ${min_ver} -- build --release

                    cd android
                    jniLibs=$(pwd)/mobile_wallet_lib/src/main/jniLibs
                    rm -rf ${jniLibs}

                    mkdir ${jniLibs}
                    mkdir ${jniLibs}/arm64-v8a
                    mkdir ${jniLibs}/armeabi-v7a
                    mkdir ${jniLibs}/x86
                    mkdir ${jniLibs}/x86_64

                    cp ../target/aarch64-linux-android/release/*.so ${jniLibs}/arm64-v8a/
                    cp ../target/aarch64-linux-android/release/deps/*.so ${jniLibs}/arm64-v8a/
                    cp ../target/armv7-linux-androideabi/release/*.so ${jniLibs}/armeabi-v7a/
                    cp ../target/armv7-linux-androideabi/release/deps/*.so ${jniLibs}/armeabi-v7a/
                    cp ../target/i686-linux-android/release/*.so ${jniLibs}/x86/
                    cp ../target/i686-linux-android/release/deps/*.so ${jniLibs}/x86/
                    cp ../target/x86_64-linux-android/release/*.so ${jniLibs}/x86_64/
                    cp ../target/x86_64-linux-android/release/deps/*.so ${jniLibs}/x86_64/

                    # Build rust library
                    cd mobile_wallet_lib
                    ./gradlew build

                    # Prepate output
                    mkdir ../../../out/
                    cp build/outputs/aar/* ../../../out/
                '''.stripIndent()
                stash includes: 'out/**/*', name: 'release'
            }
        }
        stage('Publish') {
            options { skipDefaultCheckout() }
            steps {
                unstash 'release'
                sh '''\
                    # Push to s3
                    aws s3 cp "out/${FILENAME_DEBUG}" "${S3_BUCKET}/${FILENAME}" --grants read=uri=http://acs.amazonaws.com/groups/global/AllUsers
                    aws s3 cp "out/${FILENAME_RELEASE}" "${S3_BUCKET}/${FILENAME}" --grants read=uri=http://acs.amazonaws.com/groups/global/AllUsers
                '''.stripIndent()
            }
        }
    }
}
