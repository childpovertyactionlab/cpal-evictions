pipeline {

	agent {
		label 'docker-runner-project-ntep'
	}

	environment {
		// ConfigFile[container-images]
		//    IMAGE_REPO : Image repository domain and any required prefix.
		// ConfigFile[${JOB_BASE_NAME}]
		//    EFS_AZ_IP      : Unable to resolve EFS DNS over VPC peer. Need IP of EFS in agent's availability zone.
		//    APP_ENV        : [production] signal to scripts what environment they are in
		//    CRED_ID_AWS_S3 : ID in the credential store to use for AWS S3 access

		// The tag of the containers to execute. Change this to perform a production deployment.
		APP_VERSION = 'e098f5f'

		APP_CONFIG_PATH = "${env.WORKSPACE}/.config-prod.yml"
		GACCT_PATH = "${env.WORKSPACE}/.gsuite-service.json"
		EFS_BIND_NAME = 'ntep'
		EFS_ROOT_DIR = "/binds/${EFS_BIND_NAME}"
	}

	libraries {
		lib('cpal')
	}

	stages {

		stage('Setup Environment') {
			steps {

				loadConfigsAsEnv "container-images ${JOB_BASE_NAME}"

				echo 'Acquiring configuration...'
				sh """
				aws secretsmanager get-secret-value --query SecretString --output text \
					--region us-east-1 \
					--secret-id staging/evictions/config \
					> ${env.APP_CONFIG_PATH}
				"""

				echo 'Acquiring Google Workspace credentials...'
				sh """
				aws secretsmanager get-secret-value --query SecretString --output text \
					--region us-east-1 \
					--secret-id staging/evictions/g-service-account \
					> ${env.GACCT_PATH}
				"""
			}
		}

		stage('Update Containers') {
			steps {
				sh "docker pull -q ${env.IMAGE_REPO}/ntep/acquisition:${env.APP_VERSION}"
				sh "docker pull -q ${env.IMAGE_REPO}/ntep/analysis:${env.APP_VERSION}"
				sh "docker pull -q ${env.IMAGE_REPO}/ntep/distribution:${env.APP_VERSION}"
			}
		}

		stage('Connect to Data') {
			steps {
				sh "sudo bind-nfs ${EFS_BIND_NAME} ${EFS_AZ_IP}:/ --uid 1001 --gid 1001"
				// Mounting litmus test
				sh """#!/usr/bin/env bash
				set -e
				echo \"DCAD files: \$(ls ${EFS_ROOT_DIR}/dcad-sync | wc -l)\"
				echo \"Evictions files: \$(ls ${EFS_ROOT_DIR}/evictions | wc -l)\"
				"""
			}
		}

		stage('Synchronize with DCAD') {
			steps {
				sh """#!/usr/bin/env bash
				set -e
				set -o pipefail
				(
				docker run --rm \
					--mount type=bind,src=${env.APP_CONFIG_PATH},dst=/app/config.yml \
					--mount type=bind,src=${env.EFS_ROOT_DIR}/dcad-sync,dst=/dcad-sync \
					-e ENV=${env.APP_ENV} \
					${env.IMAGE_REPO}/ntep/acquisition:${env.APP_VERSION} \
					sync-dcad-evictions.sh config.yml
				) 2>&1 | grep -vE '^= '
				"""
			}
		}

		stage('Process New Evictions') {
			steps {
				sh """
				docker run --rm \
					--mount type=bind,src=${env.APP_CONFIG_PATH},dst=/app/config.yml \
					--mount type=bind,src=${env.GACCT_PATH},dst=/var/run/secrets/google \
					-e 'GOOGLE_APPLICATION_CREDENTIALS=/var/run/secrets/google' \
					--mount type=bind,src=${env.EFS_ROOT_DIR}/evictions,dst=/data \
					--mount type=bind,src=${env.EFS_ROOT_DIR}/dcad-sync,dst=/dcad-sync,ro \
					-e ENV=${env.APP_ENV} \
					${env.IMAGE_REPO}/ntep/analysis:${env.APP_VERSION} \
					eviction-records-daily-googlesheet-processing.R
				"""
			}
		}

		stage('Generate Website Files') {
			steps {
				sh """
				docker run --rm \
					--mount type=bind,src=${env.APP_CONFIG_PATH},dst=/app/config.yml \
					--mount type=bind,src=${env.EFS_ROOT_DIR}/evictions,dst=/data \
					-e ENV=${env.APP_ENV} \
					${env.IMAGE_REPO}/ntep/analysis:${env.APP_VERSION} \
					eviction-records-ntep-join-and-clean.R
				"""
			}
		}

		stage('Push Website Updates') {
			steps {
				withCredentials([aws(
					credentialsId: "${env.CRED_ID_AWS_S3}",
					accessKeyVariable: 'AWS_ACCESS_KEY_ID',
					secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
				)]) {
					sh """
					docker run --rm \
						--mount type=bind,src=${env.APP_CONFIG_PATH},dst=/app/config.yml \
						-e AWS_ACCESS_KEY_ID \
						-e AWS_SECRET_ACCESS_KEY \
						--mount type=bind,src=${env.EFS_ROOT_DIR}/evictions,dst=/data,ro \
						-e ENV=${env.APP_ENV} \
						${env.IMAGE_REPO}/ntep/distribution:${env.APP_VERSION} \
						push-web-update.sh config.yml
					"""
				}
			}
		}

		stage('Distribute Results to 3rd Parties') {
			steps {
				withCredentials([aws(
					credentialsId: "${env.CRED_ID_AWS_S3}",
					accessKeyVariable: 'AWS_ACCESS_KEY_ID',
					secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
				)]) {
					sh """
					docker run --rm \
						--mount type=bind,src=${env.APP_CONFIG_PATH},dst=/app/config.yml \
						-e AWS_ACCESS_KEY_ID \
						-e AWS_SECRET_ACCESS_KEY \
						--mount type=bind,src=${env.EFS_ROOT_DIR}/evictions,dst=/data,ro \
						-e ENV=${env.APP_ENV} \
						${env.IMAGE_REPO}/ntep/distribution:${env.APP_VERSION} \
						push-evictions-reference.sh config.yml
					"""
				}
			}
		}

	}

	post {

		always {
			script {
				withCredentials([secretText(
					credentialsId: "chat-webhook",
					variable: 'GOOGLE_CHAT_WEBHOOK_URL'
				)]) {
					def googleChatWebhook = "${env.GOOGLE_CHAT_WEBHOOK_URL}"

					String buildResult = currentBuild.currentResult
					def statusIcons = [
						SUCCESS: 'https://emojis.slackmojis.com/emojis/images/1643514331/3045/jenkins-party.gif?1643514331',
						UNSTABLE: 'https://emojis.slackmojis.com/emojis/images/1643511247/47419/jenkins-is-fine.gif?1643511247',
						FAILURE: 'https://emojis.slackmojis.com/emojis/images/1659520601/60442/old_man_yells_at_jenkins.png?1659520601'
					]
					def colors = [SUCCESS: '#5DBCD2', UNSTABLE: '#aca620', FAILURE: '#ff0000']

					String cardTitle = "`${env.JOB_NAME}`"

					def buildStatusIcon = statusIcons[buildResult] ?: 'https://emojis.slackmojis.com/emojis/images/1643508777/51026/jenkins-worried.gif?1643508777'
					def buildStatusTitle = "<b>${currentBuild.currentResult}</b>"

					String buildVersion = "Version: <b>${env.APP_VERSION}</b>"
					String buildRuntime = "Build number ${env.BUILD_ID} took ${currentBuild.durationString}"

					sh """
					curl -X POST -H 'Content-Type: application/json' -d '{
						"cardsV2": [
							{
								"card": {
									"header": {
										"title": "${cardTitle} - ${buildStatusTitle}",
										"imageUrl": "${buildStatusIcon}"
									},
									"sections": [
										{
											"header": "Runtime Information",
											"widgets": [
												{
													"textParagraph": {
														"text": "${buildVersion}"
													}
												},
												{
													"textParagraph": {
														"text": "${buildRuntime}"
													}
												}
											]
										}
									]
								}
							}
						],
						"accessoryWidgets": [
							{
								"buttonList": {
									"buttons": [
										{
											"text": "Build Details",
											"icon": {
												"materialIcon": {
													"name": "link"
												}
											},
											"onClick": {
												"openLink": {
													"url": "${env.BUILD_URL}"
												}
											}
										}
									]
								}
							}
						]
					}' ${googleChatWebhook}
					"""
				}
			}
		}

		cleanup {
			sh "sudo bind-nfs ${EFS_BIND_NAME} ${EFS_AZ_IP}:/ --unmount"
			cleanWs()
		}
	}
}
