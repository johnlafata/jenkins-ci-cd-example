/**
 * Shared library step: buildpackPipeline
 *
 * Usage in Jenkinsfile:
 *   @Library('shared-library') _
 *   buildpackPipeline(
 *       appName: 'app1-api',
 *       configDir: 'apps/app1-api',
 *       cfOrg: 'dev',
 *       cfSpace: 'app1-space',
 *       environment: 'dev'
 *   )
 */
def call(Map config) {
    pipeline {
        agent any

        environment {
            CF_CREDS = credentials('cf-api-credentials')
            CF_API   = credentials('cf-api-endpoint')
            DOTNET_CLI_TELEMETRY_OPTOUT = '1'
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
                        env.PROJECT_FILE = appConfig.projectFile
                        env.PUBLISH_DIR  = appConfig.publishDir ?: 'published_app'
                        env.CF_MANIFEST  = "${config.configDir}/manifest-${config.environment}.yml"
                        env.BUILDPACK    = appConfig.buildpack ?: 'dotnet_core_buildpack'
                    }
                }
            }

            stage('Restore') {
                steps {
                    sh "dotnet restore ${env.PROJECT_FILE}"
                }
            }

            stage('Build') {
                steps {
                    sh "dotnet build ${env.PROJECT_FILE} --no-restore -c Release"
                }
            }

            stage('Test') {
                steps {
                    sh "dotnet test ${env.PROJECT_FILE} --no-build -c Release --logger trx"
                }
                post {
                    always {
                        step([$class: 'MSTestPublisher', testResultsFile: '**/*.trx', failOnError: false])
                    }
                }
            }

            stage('Security Scan') {
                steps {
                    sh "echo 'Scanning ${env.PROJECT_FILE}...'"
                    // TODO: dotnet tool run security-scan ${env.PROJECT_FILE}
                }
            }

            stage('Publish') {
                steps {
                    sh "dotnet publish ${env.PROJECT_FILE} -c Release --no-build -o ${env.PUBLISH_DIR}"
                    archiveArtifacts artifacts: "${env.PUBLISH_DIR}/**", fingerprint: true
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
                                -p ${env.PUBLISH_DIR} \
                                -b ${env.BUILDPACK} \
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
