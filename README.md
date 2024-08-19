# Gudz Free Land Rental Script

This script is designed for managing free land rentals in OpenSimulator, ensuring tenants maintain a regular presence to prevent users from making land unavailable without actually using it.

In the future, this script will be adjusted to also handle paid rentals.

## Features

- **Free Land Rentals**: Allows users to rent land for free, requiring them to click regularly on the rental panel to keep the parcel.
- **Full Ownership**: The land is technically sold to the user, giving them full ownership and control over their parcel without needing group tricks.
- **Automatic Reclaim**: Expired or abandoned land is sold back to the vendor owner.

## Requirements

The script requires these functions to be enabled for Estate Owners in OpenSimulator configuration:

- osDrawText
- osGetDrawStringSize
- osGetGridGatekeeperURI
- osGetGridLoginURI
- osGetNotecard
- osInviteToGroup
- osKey2Name
- osMovePen
- osSetDynamicTextureDataBlendFace
- osSetFontName
- osSetFontSize
- osSetParcelDetails
- osSetPenColor

## Usage

### For Tenants

1. **Initial Rental**: Click on the sign, read the rental conditions, and confirm the rental.
2. **Renewal**: Before the end of each term, click on the sign to renew the rental.

### For Region Owners

1. **Estate Settings**: Make sure to disable land join, split, and resell in your Estate settings.
2. **Placement**: Place the terminal outside the rented land, around 1 meter from the parcel border and adjust until the positioning beacon is inside the parcel and appears green.
3. **Confirmation**: A confirmation message appears. Check the rental conditions (see configuration below) and start renting.

## Configuration

Do not modify the script directly, any change would be overriden on next update. Use the notecard or a web URL config file instead.

### Using a Notecard

Create a notecard named `.config` including these settings:

```
configURL = https://yourgrid.org/rental/example.txt
// If set, the config will be read from the URL and the rest of the notecard will be ignored.

// Base config (required)

duration = 30       // number of days, can be decimal for shorter periods
maxDuration = 365   // number of days, can be decimal for shorter periods
renewable = TRUE
maxDuration = 3650
expireReminder = 7
expireGrace = 7

// Optional

fontname =
fontSize =
lineHeight =
margin =
textColor =
textBackgroundColor =
position =
cropToFit =
textureWidth =
textureHeight =
textureSides = 
```

### Using Object Description (deprecated)

Put these values, in this order, in the main prim description, separated by commas. Duration, max duration, expire reminder, and expire grace are in number of days.
```
DURATION,MAX_DURATION,,RENEWABLE,EXPIRE_REMINDER,EXPIRE_GRACE
```

The empty third field used to be set to MAX_PRIMS, but it is now calculated from the parcel data. It can be left empty to save space (keeping two commas for backwards compatibility).

## To Do

1. Fix current functionalities:
    - √ Fix rental not restored after updates (fixed in 1.6.5)
    - √ Fix messages not sent to HG avatars when offline (added notification queue)
    - √ Fix position not saved in rent data, causing new check triggered on reset
    - Keep notification queue after script reset
    - Clear rent data (object desc) if owner changed
    - Clear rental status if parcel changed
    - Shorter rental data format (only save in object desc the live rental data, not settings that are now handled by config file)
    - Also notify owner to clean terrain when abandoned (currently only on rental expiration)

2. Add new functionalities:
    - √ New feature: restore rental, based on prims found in the parcel (1.6.6)
    - Use different prims for sign and renter name, hide and show accordingly, to avoid resizing single prim and allow more creative designs
    - Option to limit to local grid avatars
    - Option for maximum number of parcels per user, or maximum area
    - Check that the owner has estate rights before activating
    - Centralized management
        - List available terrains
        - Centralized rental via in-world board
        - Centralized rental via web page
    - Advanced features (requires grid-side API)
        - Option to update terrain for sale status
        - Option to set objects auto return after rental end

3. Add payment system:
    - With local currency
    - On website (via w4os or WooCommerce)

## License

This script is provided under the GNU Affero General Public License version 3. See the LICENSE file for more details.
