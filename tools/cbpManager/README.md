# cbpManager-deploy

Deploy cbpManager either with with docker compose:

## Deploy the cbpManager and ShinyProxy via docker compose:

**IMPORTANT:** To change the default study directory to a custom study directory, you have to edit the line 18 of services/shinyproxy/application.yml and replace "/PATH/TO/CUSTOM/STUDY_DIR/" with the path to the study directory.
**container-volumes: ["/PATH/TO/CUSTOM/STUDY_DIR/:/srv/shiny-server/study/"]**

To use cbpManager with an authentication system you should deploy cbpManager with ShinyProxy. ShinyProxy offers different methods of authentication (see [https://www.shinyproxy.io/configuration/#authentication](https://www.shinyproxy.io/configuration/#authentication)).
Modify the `authentication` and `users` sections of the `services/shinyproxy/application.yml` file according to the description on the ShinyProxy page. 

For demonstration purpose this `application.yml` file contains the simple authentication method with the user: **admin** and password: **password**. Additionally, we have added an example configuration with Keycloak to `application.yml`. 

You can change the port of ShinyProxy by editing the `PORT` variable in the `.env` file, as well as the paths of the `STUDY_DIR` and `LOG_DIR`. Use the `.env.example` file as an example.

Start all necessary docker containers:

`docker compose up -d`

Check the application in your browser at http://localhost:8180 and log in with user: **admin** and password: **password**

## Further informations about the cbpManager:

Homepage: 		https://arsenij-ust.github.io/cbpManager/

GitHub:			https://github.com/arsenij-ust/cbpManager

Vignette:		https://arsenij-ust.github.io/cbpManager/articles/intro.html

Issues/Support:	https://github.com/arsenij-ust/cbpManager/issues

Maintainer: 	Arsenij Ustjanzew (arsenij.ustjanzew@uni-mainz.de)


