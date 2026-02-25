/**
 * Shared library step: dockerPipeline
 *
 * Usage in Jenkinsfile:
 *   @Library('shared-library') _
 *   dockerPipeline(
 *       appName: 'app1-frontend',
 *       configDir: 'apps/app1-frontend',
 *       cfOrg: 'dev',
 *       cfSpace: 'app1-space',
 *       dockerRegistry: 'gitea.<fqdn>.',
 *       environment: 'dev'
 *   )
 */
def call(Map config) {
    pipeline {
        agent any

        environment {
            CF_CREDS     = credentials('cf-api-credentials')
            DOCKER_CREDS = credentials('gitea-docker-registry')
            CF_API       = credentials('cf-api-endpoint')
        }

        stages {
            stage('Checkout') {
                steps {
                    checkout scm
                }
            }

            stage('Load Config') {
                steps {
                    script {
                        def appConfig = readYaml file: "${config.configDir}/config.yaml"
                        env.DOCKER_IMAGE = "${config.dockerRegistry}/${appConfig.docker.repository}:${BUILD_NUMBER}"
                        env.DOCKERFILE   = appConfig.dockerfile ?: 'Dockerfile'
                        env.CF_MANIFEST  = "${config.configDir}/manifest-${config.environment}.yml"
                    }
                }
            }

            stage('Docker Build') {
                steps {
                    script {
                        docker.build(env.DOCKER_IMAGE, "-f ${env.DOCKERFILE} .")
                    }
                }
            }

            stage('Security Scan') {
                steps {
                    sh "echo 'Scanning ${env.DOCKER_IMAGE}...'"
                    // TODO: trivy image --exit-code 1 --severity HIGH,CRITICAL ${env.DOCKER_IMAGE}
                }
            }

            stage('Push Image') {
                steps {
                    script {
                        docker.withRegistry("https://${config.dockerRegistry}", 'gitea-docker-registry') {
                            docker.image(env.DOCKER_IMAGE).push()
                            docker.image(env.DOCKER_IMAGE).push('latest')
                        }
                    }
                }
            }

            stage('Deploy to CF') {
                steps {
                    withCredentials([usernamePassword(credentialsId: 'cf-api-credentials', usernameVariable: 'CF_USER', passwordVariable: 'CF_PASS')]) {
                        sh """
                            cf api ${CF_API} --skip-ssl-validation
                            cf auth \$CF_USER \$CF_PASS
                            cf target -o ${config.cfOrg} -s ${config.cfSpace}
                            cf push ${config.appName} \
                                --docker-image ${env.DOCKER_IMAGE} \
                                --docker-username \$DOCKER_CREDS_USR \
                                -f ${env.CF_MANIFEST}
                        """
                    }
                }
            }

            stage('Smoke Test') {
                steps {
                    script {
                        def route = sh(script: "cf app ${config.appName} | grep routes | awk '{print \$2}'", returnStdout: true).trim()
                        sh "curl -sf --max-time 30 https://${route}/health || exit 1"
                    }
                }
            }
        }

        post {
            success { echo "Deployed ${config.appName} to ${config.cfOrg}/${config.cfSpace}" }
            failure { echo "FAILED: ${config.appName}" }
            always  { cleanWs() }
        }
    }
}
