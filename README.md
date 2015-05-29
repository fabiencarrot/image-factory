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
* inject private key to bind
* sky is the limit

TODO:
cleanup volumes