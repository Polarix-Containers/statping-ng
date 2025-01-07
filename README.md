# Statping-ng

![Build, scan & push](https://github.com/Polarix-Containers/statping-ng/actions/workflows/build.yml/badge.svg)
![Build dev, scan & push](https://github.com/Polarix-Containers/statping-ng/actions/workflows/build-dev.yml/badge.svg)

### Features & usage
- Rebases the [official image](https://github.com/statping-ng/statping-ng) to the latest Alpine, to be used as a drop-in replacement.
- Statping binary built with the latest Alpine Golang container.
- ⚠️ The frontend is built with End-of-Life Node.js 16. Our attempts to bump the Node.js version were unsuccessful.
- ⚠️ Node.js and Golang build dependencies are very old and have not been updated in years. No attempt to bump dependency versions have been made by us.
- Unprivileged image: you should check your volumes' permissions (eg `/data`), default UID/GID is 200008.

### Licensing
- Licensed under GPL 3 to comply with licensing by Statping-ng.
- Any image built by Polarix Containers is provided under the combination of license terms resulting from the use of individual packages.
