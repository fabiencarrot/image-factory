# 5 Minutes Stacks, épisode deux : WordPress

## Episode deux : Wordpress

Dans la galaxie des CMS Open-Source, WordPress figure en bonne place en termes de communauté, de fonctionnalités et d'adoption. La société Automattic, qui développe et distribue WordPress, fourni une offre SaaS permettant de créer son blog en quelques minutes. Pour autant, ceux qui en ont fait l'expérience savent qu'on se retrouve rapidement limité par le cadre d'hébergement de wordpress.com.

Aujourd'hui nous mettons à votre disposition de quoi démarrer votre instance WordPress en quelques minutes et rester maître à bord pour la faire vivre.

La base de déploiement est une instance unique Ubuntu Trusty. Les serveurs Apache et MySQL sont déployés sur ce serveur et paramétrés via [Ansible](http://http://docs.ansible.com/).

## Préparatifs

Les pré-requis pour déployer cette stack :

* un accès internet
* un shell Linux
* un [compte Cloudwatt](https://www.cloudwatt.com/authentification), avec une [paire de clés existante](https://console.cloudwatt.com/project/access_and_security/?tab=access_security_tabs__keypairs_tab)
* les outils [OpenStack CLI](http://docs.openstack.org/cli-reference/content/install_clients.html)
* un clone local du dépôt git [5-minutes-lamp](http://localhost)

## Tour du propriétaire

Une fois le repository cloné, vous trouvez :

* ```5min-trusty-wordpress.heat.yml``` : Template d'orchestration HEAT, qui va servir à déployer l'infrastructure nécessaire et lancer la configuration automatique.
* ```ansible``` : Répertoire de ressources Ansible pour la mise en place de la partie applicative.
* ```stack-start.sh``` : Script de lancement de la stack. C'est un micro-script pour vous économiser quelques copier-coller.
* ```stack-get-url.sh``` : Script de récupération de l'IP d'entrée de votre stack.

## Démarrage

### Initialiser l'environnement

Munissez-vous de vos identifiants Cloudwatt, et cliquez [ICI](https://console.cloudwatt.com/project/access_and_security/api_access/openrc/). Si vous n'êtes pas connecté, vous passerez par l'écran d'authentification, puis vous le téléchargement d'un script démarrera. C'est grâce à celui-ci que vous pourrez initialiser les accès shell aux API Cloudwatt.

Sourcez le fichier téléchargé dans votre shell. Votre mot de passe vous sera demandé. 

```
$ source COMPUTE-[...]-openrc.sh
Please enter your OpenStack Password:

```

Une fois ceci fait, les outils ligne de commande OpenStack peuvent interagir avec votre compte Cloudwatt.

### Ajuster les paramètres

Dans le fichier ```5min-trusty-wordpress.heat.yml``` vous trouverez en haut une section ```parameters```. Le seul paramètre obligatoire à ajuster est celui nommé ```keypair_name``` dont la valeur ```default``` doit contenir le nom d'une paire de clés valide dans votre compte utilisateur.

```
heat_template_version: 2013-05-23


description: All-in-one Wordpress stack


parameters:
  keypair_name:
    default: amaury-ext-compute         <-- Mettez ici le nom de votre paire de clés
    description: Keypair to inject in instances
    type: string

[...]
```

### Démarrer la stack

Dans un shell, lancer le script ```stack-start.sh``` en passant en paramètre le nom que vous souhaitez lui attribuer :

```
$ ./stack-start.sh LE_BIDULE
+--------------------------------------+------------+--------------------+----------------------+
| id                                   | stack_name | stack_status       | creation_time        |
+--------------------------------------+------------+--------------------+----------------------+
| ed4ac18a-4415-467e-928c-1bef193e4f38 | LE_BIDULE  | CREATE_IN_PROGRESS | 2015-04-21T08:29:45Z |
+--------------------------------------+------------+--------------------+----------------------+
```

Enfin, attendez 5 minutes que le déploiement soit complet.

### Enjoy

Une fois tout ceci fait, vous pouvez lancez le script ```stack-get-url.sh``` en passant en paramètre le nom de la stack.

```
./stack-get-url.sh LE_BIDULE
LE_BIDULE 82.40.34.249
```

qui va récupérer l'IP flottante attribuée à votre stack. Vous pouvez alors attaquer cette IP avec votre navigateur préféré et commencer à configurer votre instance Wordpress.

## Dans les coulisses

Le script start-stack.sh s'occupe de lancer les appels nécessaires sur les API Cloudwatt pour :

* démarrer une instance basée sur Ubuntu Trusty Tahr
* faire une mise à jour de tous les paquets système
* installer Apache, PHP, MySQL et Wordpress dessus
* configurer MySQL avec un utilisateur et une base dédiés à WordPres, avec mot de passe généré
* l'exposer sur Internet via une IP flottante

## So watt ?

Ce tutoriel a pour but d'accélerer votre démarrage. A ce stade vous êtes maître(sse) à bord. 

Vous avez un point d'entrée sur votre machine virtuelle en ssh via l'IP flottante exposée et votre clé privée (utilisateur ```cloud``` par défaut).

Les chemins intéressants sur votre machine :

- ```/usr/share/wordpress``` : Répertoire d'installation de WordPress.
- ```/var/lib/wordpress/wp-content``` : Répertoire de données spécifiques à votre instance Wordpress (thèmes, médias, ...).
- ```/etc/wordpress/config-default.php``` : Fichier de configuration de WordPress, dans lequel se trouve le mot de passe du user MySQL, généré pendant l'installation.



Have fun. 

Hack in peace.