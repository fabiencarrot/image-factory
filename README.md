# Image Factory

Pré-requis :

* openstack heat client

Steps :

* template heat avec keypair et système debian based comme base
* tunnel ssh pour la commm avec jenkins
* ajout git plugin + maj plugins
* credentials OS dans .profile
* restart jenkins
* job de test avec heat stack-list
* sky is the limit