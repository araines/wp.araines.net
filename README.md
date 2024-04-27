# araines.net

Static serverless WordPress site for my personal blog

## Initial setup

1. Initialise terraform

```
terraform init
```

2. Set up initial WordPress build

```
terraform apply
```

3. Start up WordPress (see below) and navigate to the admin interface

4. Change the admin password

5. Install and activate the `GeneratePass` theme

6. Customise the theme

   a. The following colours:

   ```
   contrast:   #222222
   contrast-2: #bc986a
   contrast-3: #daad86
   base:       #fbeec1
   base-2:     #659dbd
   base-3:     #ffffff
   accent:     #7e783a
   ```

   b. Change "Entry meta text" to `accent`

7. Go to Settings->Permalinks and select Post Name

8. Go to Settings->General and configure timezones, language etc

9. Go to Settings->Discussion and disable everything in "Default post settings"

10. Install and activate `Yoast SEO` plugin (consider Rank Math?)

11. Install and activate `UpdraftPlus` plugin for backups / local dev

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

### First-time Setup

1. Login to `wp-admin`.

2. Go to WP2Static->Addons and enable the S3 deployment addon.

3. Click the settings cog and change the Object ACL to `private`, then Save S3 Options.

### Normal publication

To publish the site statically, login to `wp-admin`, then go to WP2Static and press Generate Static Site.

## Accessing WordPress

Go to the WordPress dynamic website at [wordpress.food.araines.net](http://wordpress.food.araines.net).

The admin interface can be accessed by [wp-admin](http://wordpress.food.araines.net/wp-admin).

## Troubleshooting

### Generate static site: Unable to fetch URL contents

During the static site generation, if it gets a 500 error with the last log being "Unable to fetch URL contents" then try clearing the caches.

## TODO

Configure OIDC (separate repo?) to allow GitHub actions to talk to AWS
Set up GitHub actions with AWS
Create an action for building docker container and pushing to ECR
Update the apache2-endpoint.sh to work in the ECR environment (with correct DNS/IPs etc)
Update the apache2-endpoint.sh to update R53 so container is accessible
Set up multisite
Update the apache2-endpoint.sh to install GP Premium / recipe plugins / backup plugins / etc
