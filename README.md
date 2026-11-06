# docker-ocserv

docker-ocserv is an OpenConnect VPN Server boxed in a Docker image built by [Tommy Lau](mailto:tommy@gen-new.com).

## Update on Aug 31, 2017

Update to version 0.11.8 and use Alpine 3.6 as base image

## Update on July 16, 2016

Thanks for [@sempr](https://github.com/sempr)'s contribution and suggestion, from now on, the [Alpine Linux](https://hub.docker.com/_/alpine/) will be used as the base image. The docker image size has been dramatically reduced from around 150MB to only 20MB.

> NOTICE: You have to use Docker version 1.9.0 or later to support Alpine, DO NOT UPDATE the image if your Docker version is older than 1.9.0



## What is OpenConnect Server?

[OpenConnect server (ocserv)](http://www.infradead.org/ocserv/) is an SSL VPN server. It implements the OpenConnect SSL VPN protocol, and has also (currently experimental) compatibility with clients using the [AnyConnect SSL VPN](http://www.cisco.com/c/en/us/support/security/anyconnect-vpn-client/tsd-products-support-series-home.html) protocol.

## How to use this image

Get the docker image by running the following commands:

```bash
docker pull tommylau/ocserv
```

Start an ocserv instance:

```bash
docker run --name ocserv --privileged -p 443:443 -p 443:443/udp -e VPN_USER=alice -e VPN_PASSWORD=changeme -d tommylau/ocserv
```

This will start an instance with a user named `alice` and password `changeme`. No default user is created: you must either set `VPN_USER`/`VPN_PASSWORD` or mount your own `ocpasswd` file, otherwise the container exits with an error.

### Environment Variables

Apart from the VPN user (see `VPN_USER` / `VPN_PASSWORD` below, or mount an `ocpasswd` file), all variables are optional.

`CA_CN`, this is the common name used to generate the CA(Certificate Authority).

`CA_ORG`, this is the organization name used to generate the CA.

`CA_DAYS`, this is the expiration days used to generate the CA.

`SRV_CN`, this is the common name used to generate the server certification.

`SRV_ORG`, this is the organization name used to generate the server certification.

`SRV_DAYS`, this is the expiration days used to generate the server certification.

`VPN_USER` and `VPN_PASSWORD`, the username and password of a VPN user. Both must be set together. The user is created (or its password updated) in `/etc/ocserv/ocpasswd` on every container start; other users in the file are left untouched.

`CAMOUFLAGE_SECRET`, when set, enables ocserv's camouflage mode: the server answers like an ordinary password-protected web server unless the client puts the secret in the URL, e.g. `https://my.test.com/?mysecret`. It may contain only letters, digits and `. _ ~ -`. When not set, camouflage is disabled.

`CAMOUFLAGE_REALM`, the HTTP auth realm shown to clients without the secret (only used when `CAMOUFLAGE_SECRET` is set).

`DTLS`, `true` or `false`. When `false`, the UDP (DTLS) channel is turned off and clients use TCP/TLS only; you then don't need to publish `443/udp`.

`COMPRESSION`, `true` or `false`. Enables or disables LZS/LZ4 compression negotiation.

The default values of the above environment variables:

|   Variable   |     Default     |
|:------------:|:---------------:|
|  **CA_CN**   |      VPN CA     |
|  **CA_ORG**  |     Big Corp    |
| **CA_DAYS**  |       9999      |
|  **SRV_CN**  | www.example.com |
| **SRV_ORG**  |    My Company   |
| **SRV_DAYS** |       9999      |
| **VPN_USER** |      (none)     |
| **VPN_PASSWORD** |  (none)     |
|   **DTLS**   |       true      |
| **COMPRESSION** |    true      |
| **CAMOUFLAGE_SECRET** | (none, camouflage disabled) |
| **CAMOUFLAGE_REALM** | Restricted Content |

### Running examples

Start an instance with username `alice` and password `changeme`

```bash
docker run --name ocserv --privileged -p 443:443 -p 443:443/udp -e VPN_USER=alice -e VPN_PASSWORD=changeme -d tommylau/ocserv
```

Start an instance with camouflage enabled; clients must connect to `https://<server>/?mysecret`

```bash
docker run --name ocserv --privileged -p 443:443 -p 443:443/udp -e VPN_USER=alice -e VPN_PASSWORD=changeme -e CAMOUFLAGE_SECRET=mysecret -d tommylau/ocserv
```

Start an instance with server name `my.test.com`, `My Test` and `365` days

```bash
docker run --name ocserv --privileged -p 443:443 -p 443:443/udp -e SRV_CN=my.test.com -e SRV_ORG="My Test" -e SRV_DAYS=365 -e VPN_USER=alice -e VPN_PASSWORD=changeme -d tommylau/ocserv
```

Start an instance with CA name `My CA`, `My Corp` and `3650` days

```bash
docker run --name ocserv --privileged -p 443:443 -p 443:443/udp -e CA_CN="My CA" -e CA_ORG="My Corp" -e CA_DAYS=3650 -e VPN_USER=alice -e VPN_PASSWORD=changeme -d tommylau/ocserv
```

A totally customized instance with both CA and server certification

```bash
docker run --name ocserv --privileged -p 443:443 -p 443:443/udp -e CA_CN="My CA" -e CA_ORG="My Corp" -e CA_DAYS=3650 -e SRV_CN=my.test.com -e SRV_ORG="My Test" -e SRV_DAYS=365 -e VPN_USER=alice -e VPN_PASSWORD=changeme -d tommylau/ocserv
```

Start an instance as above but with your own `ocpasswd` file instead of `VPN_USER`/`VPN_PASSWORD`

```bash
docker run --name ocserv --privileged -p 443:443 -p 443:443/udp -e CA_CN="My CA" -e CA_ORG="My Corp" -e CA_DAYS=3650 -e SRV_CN=my.test.com -e SRV_ORG="My Test" -e SRV_DAYS=365 -v /some/path/to/ocpasswd:/etc/ocserv/ocpasswd -d tommylau/ocserv
```

**WARNING:** ocserv needs at least one user to start. If neither `VPN_USER`/`VPN_PASSWORD` nor a non-empty `/etc/ocserv/ocpasswd` is provided, the container exits immediately with an error.

### User operations

All the users opertaions happened while the container is running. If you used a different container name other than `ocserv`, then you have to change the container name accordingly.

#### Add user

If say, you want to create a user named `tommy`, type the following command

```bash
docker exec -ti ocserv ocpasswd -c /etc/ocserv/ocpasswd tommy
Enter password:
Re-enter password:
```

When prompt for password, type the password twice, then you will have the user with the password you want.

#### Delete user

Delete user is similar to add user, just add another argument `-d` to the command line

```bash
docker exec -ti ocserv ocpasswd -c /etc/ocserv/ocpasswd -d tommy
```

The above command will delete the user `tommy`. Note that the user given in `VPN_USER` is re-created on the next container start as long as the variable is set.

#### Change password

Change password is exactly the same command as add user, please refer to the command mentioned above.
