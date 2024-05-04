# araines.net

Static serverless WordPress site for my personal blog

## Initial setup

1. Initialise terraform

```
terraform init
```

2. Set up OIDC with GitHub actions

```
terraform apply -target module.wordpress.module.github-oidc
```

3. Set up initial WordPress build

```
terraform apply
```

4. Start up WordPress (see below) and navigate to the admin interface

5. Change the admin password

6. Customise the theme

   a. TODO

## Starting / stopping WordPress

To start up WordPress:

```
terraform apply -var="launch=1"
```

To shut down WordPress:

```
terraform apply
```

## Site publication

### Normal publication

To publish the site statically, login to `wp-admin`, then go to WP2Static and press Generate Static Site.

## Accessing WordPress

Go to the WordPress dynamic website at [wordpress.araines.net](http://wordpress.araines.net).

The admin interface can be accessed by [wp-admin](http://wordpress.araines.net/wp-admin).

## Troubleshooting

### Generate static site: Unable to fetch URL contents

During the static site generation, if it gets a 500 error with the last log being "Unable to fetch URL contents" then try clearing the caches.
