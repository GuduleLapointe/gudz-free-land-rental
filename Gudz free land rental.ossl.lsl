/**
 * Gudule's free land rental
 *
 * @Version 1.5-dev-2
 * @author Gudule Lapointe gudule.lapointe@speculoos.world:8002
 * @licence  GNU Affero General Public License
 *
 * Allow to rent land for free, requiring the user to click regularly on the
 * rental panel to keep the parcel. The land is technically sold as with viewer
 * buy/send land so the user has full ownership and full control on his parcel,
 * no need of the group trick. Expired or abandonned land is sold back to the
 * vendor owner.
 *
 * IMPORTANT:
 * - Disable land join,split and resell in your Estate settings
 * - The terminal HAS TO BE outside the rented land. Place it at 1 meter of the
 *   rented land border (outside) and adjust to make sure the yellow positioning
 *   mark appears inside.
 *
 * Configuration:
 * - With Object Description :
 *   Put these values, in this order, in the main prim description, separated by commas
 *   DURATION,MAX_DURATION,MAX_PRIMS,RENEWABLE,EXPIRE_REMINDER,EXPIRE_GRACE
 *
 * - With a notecard:
 *   Create a note card named ".config" including these settings:
 *   // Base config (required)
 *     duration = 30 // number of days, can be decimal for shorter periods
 *     maxDuration = 365 // number of days, can be decimal for shorter periods
 *     maxPrims = 1000 // Note sure we use it, though
 *     renewable =
 *     expireReminder =
 *     expireGrace =
 *
 *   // Optional
 *     *     fontname =
 *     fontSize =
 *     lineHeight =
 *     margin =
 *     textColor =
 *     backgroundColor =
 *     position =
 *     cropToFit =
 *     textureWidth =
 *     textureHeight =
 *     textureSides") textureSides = llParseString2List(val, ",", " =
 *
 */

// User configurable variables:
integer DEBUG = FALSE;    // set to TRUE to see debug info
vector parcelDistance = <0,2,0>; // distance between the rental sign and the parcel (allow to place the sign outside the parcel)
integer checkerLink = 4;

// named texture have to be placed in the prim inventory:
string texture_expired = TEXTURE_BLANK;          // lease is expired
string texture_unleased = "texture_unleased";     // leased signage, large size
string texture_busy = TEXTURE_BLANK;       // busy signage
string texture_leased = TEXTURE_BLANK;               // leased  - in use

vector SIZE_UNLEASED = <1,0.2,0.5>;        // the signs size when unrented
vector SIZE_LEASED = <1,0.2,0.125>;        // the signs size when rented (it will shrink)

string configFile = ".config";
string statusFile = "~status";
integer configured = FALSE;

// End of user configurable variables

// Put this in the Description of the sign prim or you will get default ones
// DURATION,MAX_DURATION,MAX_PRIMS,RENEWABLE,EXPIRE_REMINDER,EXPIRE_GRACE
//
// DURATION: rental and renewal period in days
// MAX_DURATION: the maximum total rental, renewals included
// MAX_PRIMS (obsolete, calculated automatically)
// RENEWABLE: if set to 1, or TRUE, user can renew, if set to 0, the user cannot renew the same plot
// EXPIRE_REMINDER: when to send an IM warning for renewal, in number of days before the lease expiration (if RENEWABLE)
// EXPIRE_GRACE: number of days allowed to miss claiming before it really expires

// Copyright (C) 2016  Gudule Lapointe gudule@speculoos.world
// Based "No Money Rental (Vendor).lsl" script from Outworldz website

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.


// Default config info if you didn't change the description when this script is first executed
//string  initINFO = "1,7,100,1,3,1"; // daily rental, max 7 days
//string  initINFO = "7,28,100,1,3,1"; // daily rental, max 1 month
string  initINFO = "30,3650,100,1,7,7"; // montly rental, max 10 years
string  DEBUGINFO  = "0.041,1,100,1,0.0104,1"; // Default config info in debug mode if you didn't change the description when this script is first executed (1 hour rental, max 1 day, warn 4h before, grace 1 day)
//string  debugINFO = "0.00347222,0.00694455,100,1,0.00138889, 0.00138889";  //fast timers (5 minutes rental, max 10 min, warn 2 min before, grace 1 minute))
// Debug config info, 5 minutes per claim, 10 minutes max, 100 prims, 2 minute warning, grace period 1 minutes

/**
 * DO NOT CHANGE ANYTHING BELOW THIS.
 * Or don't complain.
 */

float DURATION;     // DAYS  lease is claimed
float MAX_DURATION;  // maximum length in days
integer MAX_PRIMS;    // number of prims
integer RENEWABLE = FALSE; // can they renew?
float EXPIRE_REMINDER ; //Day allowed to renew earlier
float EXPIRE_GRACE ; // Days allowed to miss payment

vector TERMINAL_POS; // Last position of the terminal
integer MY_STATE = 0;  // 0 is unleased, 1 = leased
string LEASER = "";    // name of lessor
key LEASERID;          // their UUID
integer LEASED_UNTIL; // unix time stamp
integer DAYSEC = 86400;         // a constant
integer SENT_WARNING = FALSE;    // did they get an im?
integer SENT_PRIMWARNING = FALSE;    // did they get an im about going over prim count?
integer listener;    // ID for active listener
key touchedKey ;     // the key of whoever touched us last (not necessarily the renter)
float touchStarted;

vector parcelPos;
vector signPos;
integer parcelArea;
list parcelDetails;

integer IDX_DURATION = 0;
integer IDX_MAX_DURATION = 1;
integer IDX_MAX_PRIMS = 2;
integer IDX_RENEWABLE = 3;
integer IDX_EXPIRE_REMINDER = 4;
integer IDX_EXPIRE_GRACE = 5;
integer IDX_MY_STATE = 6;
integer IDX_LEASER = 7;
integer IDX_LEASERID = 8;
integer IDX_LEASED_UNTIL = 9;
integer IDX_SENT_WARNING = 10;
integer IDX_TERMINAL_POS = 11;
integer firstLaunch = TRUE;

debug(string data)
{
    if (DEBUG)
        llOwnerSay("DEBUG: " + data);
}
statusUpdate(string data)
{
    llOwnerSay(data);
}

integer isRented()
{
    list data = trimmedCSV2list(llGetObjectDesc()); // Parse the CSV data
    return ( llList2Integer(data, IDX_MY_STATE) == TRUE );
}

string rentalInfo() {
    return "Rented by  " + LEASER
    + " until " + Unix2PST_PDT(LEASED_UNTIL)
    // + " remaining " + secondsToHumanFormat(LEASED_UNTIL - llGetUnixTime()) + ")"
    ;
}

string rentalConditions() {
    if(isRented()) return rentalInfo();

    return "\nRental conditions: "
    + "\n    Desc " + llGetObjectDesc()
    + "\n    Duration " + daysToHumanFormat(DURATION)
    + "\n    Renewable " + ( RENEWABLE ? "yes" : "no")
    + ( RENEWABLE && MAX_DURATION > 0 ? " (maximum " + daysToHumanFormat(MAX_DURATION) + ")" : "" )
    + "\n    Max prims " + MAX_PRIMS
    + "\n    Expiration reminder " + daysToHumanFormat(EXPIRE_REMINDER) + " before"
    + "\n    Grace period " + daysToHumanFormat(EXPIRE_GRACE) + " after"
    + "\nPlease read the covenant before renting"
    ;
}

integer dialogActiveFlag ;    // TRUE when we have up a dialog box, used by the timer to clear out the listener if no response is given
dialog()
{
    llListenRemove(listener);
    integer channel = llCeil(llFrand(1000000)) + 100000 * -1; // negative channel # cannot be typed
    listener = llListen(channel,"","","");
    if(isRented() )
    {
        llDialog(touchedKey,
        "Leased until " + Unix2PST_PDT(LEASED_UNTIL)
        + ". Abandon land?"
        ,["Abandon","-","No"],channel);
    } else {
        llDialog(touchedKey,"Do you wish to claim this parcel?",["Yes","-","No"],channel);
    }
    llSetTimerEvent(30);
    llSetText("",<1,0,0>, 1.0);
    //llInstantMessage(LEASERID,"Your parcel is ready.\n" + get_rentalbox_url());

    dialogActiveFlag  = TRUE;
}

string get_rentalbox_info()
{
    return llGetRegionName()  + " @ " + (string)parcelPos + " (Renter: \"" + LEASER + "\", Expire: " + secondsToHumanFormat(LEASED_UNTIL - llGetUnixTime()) + ")";
}
string get_rentalbox_url()
{
    return "secondlife://" + strReplace(osGetGridGatekeeperURI(), "http://", "") + "/" + llGetRegionName() + "/";
    // + (string)parcelPos.x + "," + (string)parcelPos.y + "," + (string)parcelPos.z;
}

list trimmedCSV2list ( string data ) {
    return llParseStringKeepNulls(data, [","], [] );
}


integer strToBoolean(string input)
{
    input = llToLower(input);
    if (input == "true" || input == "yes" || input == "1")
    {
        return TRUE;
    }
    return FALSE;
}


load_data()
{
    integer len;
    string desc = llGetObjectDesc();
    list data = trimmedCSV2list(desc);

    if (llStringLength(desc) < 5) // SL does not allow blank description
    {
        data = trimmedCSV2list(initINFO);
    }
    else if (DEBUG)
    {
        data = trimmedCSV2list(DEBUGINFO);    // 5 minute fast timers
    }

    // Should be 6 for unconfigured and 11 for configured and in action
    len = llGetListLength(data);

    // Extract data
    DURATION = llList2Float(data, IDX_DURATION);
    MAX_DURATION = llList2Float(data, IDX_MAX_DURATION);
    MAX_PRIMS = llGetParcelMaxPrims(parcelPos, FALSE); // Get from parcel
    RENEWABLE = strToBoolean(llList2String(data, IDX_RENEWABLE));
    EXPIRE_REMINDER = llList2Float(data, IDX_EXPIRE_REMINDER);
    EXPIRE_GRACE = llList2Float(data, IDX_EXPIRE_GRACE);

    string mystate_check = llList2String(data, IDX_MY_STATE);
    MY_STATE = (integer)mystate_check;
    LEASERID = (key)llList2String(data, IDX_LEASERID);
    LEASER = llKey2Name(LEASERID);
    LEASED_UNTIL = llList2Integer(data, IDX_LEASED_UNTIL);
    SENT_WARNING = llList2Integer(data, IDX_SENT_WARNING);
    TERMINAL_POS = llList2Vector(data, IDX_TERMINAL_POS);

    configured = ( mystate_check != "" );

}

save_data()
{
    debug("Data saved in description");
    // Prepare data, don
    list data =  [
    unTrailFloat(DURATION),                 // 0: IDX_DURATION
    unTrailFloat(MAX_DURATION),              // 1: IDX_MAX_DURATION
    "",                // 2: IDX_MAX_PRIMS (deprecated, dynamic value)
    (string)RENEWABLE,           // 3: IDX_RENEWABLE
    unTrailFloat(EXPIRE_REMINDER),            // 4: IDX_EXPIRE_REMINDER
    unTrailFloat(EXPIRE_GRACE),            // 5: IDX_EXPIRE_GRACE
    (string)MY_STATE,               // 6: IDX_MY_STATE
    "",                 // 7: IDX_LEASER (deprecated, dynamic value)
    ( LEASERID == NULL_KEY ? "" : (string)LEASERID ),  // 8: IDX_LEASERID
    (string)LEASED_UNTIL,           // 9: IDX_LEASED_UNTIL
    (string)SENT_WARNING,           // 10: IDX_SENT_WARNING
    unTrailVector(TERMINAL_POS)           // 11: IDX_TERMINAL_POS
    ];

    string descConfig = llDumpList2String(data, ",");
    llSetObjectDesc(descConfig);

    // llOwnerSay("descConfig " + descConfig);
    initINFO = descConfig;   // for debugging in LSL Editor.
    DEBUGINFO = initINFO;  // for debugging in fast mode

    getConfig() ;    // to print it in case of debug
}

reclaimParcel()
{
    LEASER="";
    LEASERID=NULL_KEY;
    list rules =[
        PARCEL_DETAILS_NAME, parcelArea + " sqm parcel for rent",
        PARCEL_DETAILS_DESC, "Free rental; "
        + parcelArea + " sqm; "
        + MAX_PRIMS + " prims allowed. "
        + "Click the rental sign to claim this land.",
        PARCEL_DETAILS_OWNER, llGetOwner(),
        PARCEL_DETAILS_GROUP, llList2Key(llGetObjectDetails(llGetKey(), [OBJECT_GROUP]), 0),
        PARCEL_DETAILS_CLAIMDATE, 0];
    osSetParcelDetails(parcelPos, rules);
    save_data();
}

string strReplace(string str, string search, string replace) {
    return llDumpList2String(llParseStringKeepNulls((str),[search],[]),replace);
}

string secondsToHumanFormat(float insecs) {
    return daysToHumanFormat(insecs / 86400);
}

string daysToHumanFormat(float indays)
{
    integer days = (integer)indays;
    integer hours = (integer)((indays - days) * 24);

    integer years = 0;
    while (days >= 365)
    {
        years++;
        days -= 365;
    }

    integer months = 0;
    while (days >= 30)
    {
        months++;
        days -= 30;
    }

    string timeString = "";
    if (years > 0)
    {
        timeString += (string)years + " year" + (years > 1 ? "s" : "");
        if (days >= 5) // Display years and days for 5 or more remaining days
            timeString += " " + (string)days + " day" + (days > 1 ? "s" : "");
        else if (days > 0) // Display years and remaining days for less than 5 remaining days
            timeString += " " + (string)days + " day" + (days > 1 ? "s" : "") + " remaining";
    }
    else if (months > 0)
    {
        timeString += (string)months + " month" + (months > 1 ? "s" : "");
        if (days > 0 || hours > 0)
            timeString += " ";
    }
    else if (days > 0)
    {
        timeString += (string)days + " day" + (days > 1 ? "s" : "");
        if (hours > 0)
            timeString += " ";
    }
    if (hours > 0)
    {
        timeString += (string)hours + " hour" + (hours > 1 ? "s" : "");
    }

    if (timeString == "")
        timeString = "0 minutes";

    return timeString;
}

string Unix2PST_PDT(integer insecs)
{
    string str = Unix2PST_PDT_pre_process(insecs - (3600 * 8) );   // PST is 8 hours behind GMT
    if (llGetSubString(str, -3, -1) == "PDT")     // if the result indicates Daylight Saving Time ...
        str = Unix2PST_PDT_pre_process(insecs - (3600 * 7) );      // ... Recompute at 1 hour later
    return str;
}

// Unix2PST_PDT_pre_process Unix Time to SLT, identifying whether it is currently PST or PDT (i.e. Daylight Saving aware)
// Omei Qunhua December 2013
list weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

// This leap year test is correct for all years from 1901 to 2099 and hence is quite adequate for Unix Time computations
integer LeapYear(integer year)
{
    return !(year & 3);
}

integer DaysPerMonth(integer year, integer month)
{
    if (month == 2)      return 28 + LeapYear(year);
    return 30 + ( (month + (month > 7) ) & 1);           // Odd months up to July, and even months after July, have 31 days
}

string Unix2PST_PDT_pre_process(integer insecs)
{
    integer w; integer month; integer daysinyear;
    integer mins = insecs / 60;
    integer secs = insecs % 60;
    integer hours = mins / 60;
    mins = mins % 60;
    integer days = hours / 24;
    hours = hours % 24;
    integer DayOfWeek = (days + 4) % 7;    // 0=Sun thru 6=Sat

    integer years = 1970 +  4 * (days / 1461);
    days = days % 1461;                  // number of days into a 4-year cycle

    @loop;
    daysinyear = 365 + LeapYear(years);
    if (days >= daysinyear)
    {
        days -= daysinyear;
        ++years;
        jump loop;
    }
    ++days;
    //for (w = month = 0; days > w; )
    w = 0;
    month = 0;
    do {
        days -= w;
        w = DaysPerMonth(years, ++month);
    } while (days > w);
    string str =  ((string) years + "-" + llGetSubString ("0" + (string) month, -2, -1) + "-" + llGetSubString ("0" + (string) days, -2, -1) + " " +
    llGetSubString ("0" + (string) hours, -2, -1) + ":" + llGetSubString ("0" + (string) mins, -2, -1) );

    integer LastSunday = days - DayOfWeek;
    string PST_PDT = " PST";                  // start by assuming Pacific Standard Time
    // Up to 2006, PDT is from the first Sunday in April to the last Sunday in October
    // After 2006, PDT is from the 2nd Sunday in March to the first Sunday in November
    if (years > 2006 && month == 3  && LastSunday >  7)     PST_PDT = " PDT";
    if (month > 3)                                          PST_PDT = " PDT";
    if (month > 10)                                         PST_PDT = " PST";
    if (years < 2007 && month == 10 && LastSunday > 24)     PST_PDT = " PST";
    return (llList2String(weekdays, DayOfWeek) + " " + str + PST_PDT);
}

checkValidPosition()
{
    debug("checking position");
    vector currentPos = llGetPos() + parcelDistance * llGetRot();
    if(parcelPos != currentPos)
    {
        debug("position was " + (string)parcelPos + " and is now " + (string)currentPos);
        state waiting;
    }
    debug("checking marker");
    currentPos = llList2Vector(llGetLinkPrimitiveParams(checkerLink, [ PRIM_POS_LOCAL ]), 0);
    if(currentPos != <0,0,0>)
    {
        debug("marker is out: " + (string)currentPos);
        state waiting;
    }
}

string fontName = "Sans";
integer fontSize = 36;
integer lineHeight = 36;
integer margin = 24;
string textColor = "Black";
string backgroundColor = "White";
string position = "center";
integer cropToFit = TRUE;
integer textureWidth = 512;
integer textureHeight = 64;
list textureSides = [ 1,3 ];
//string otherTexture = TEXTURE_BLANK;

getConfig()
{
    load_data();
    if (llGetInventoryType(configFile) != INVENTORY_NOTECARD)
    {
        debug("no config file, using defaults");
        return;
    }

    list lines = llParseString2List(osGetNotecard(configFile), "\n", "");
    loadConfigLines(lines);
}

reloadConfig() {
    llOwnerSay("Reloading config");
    getConfig();
    llOwnerSay(rentalConditions());
}
loadConfigLines(list lines) {
    integer count = llGetListLength(lines);
    integer i = 0;
    do
    {
        string line = llStringTrim(llList2String(lines, i), STRING_TRIM);
        if (llGetSubString(line, 0, 1) != "//" && llSubStringIndex(line, "=") > 0)
        {
            list params = llParseString2List(line, ["="], []);
            string var = llToLower(llStringTrim(llList2String(params, 0), STRING_TRIM)); // Convert to lowercase
            string val = llStringTrim(llList2String(params, 1), STRING_TRIM);
            debug(var + "=" + val);

            // Existing variables
            if (var == "fontname") fontName = val;
            else if (var == "fontsize") fontSize = (integer)val;
            else if (var == "lineheight") lineHeight = (integer)val;
            else if (var == "margin") margin = (integer)val;
            else if (var == "textcolor") textColor = val;
            else if (var == "backgroundcolor") backgroundColor = val;
            else if (var == "position") position = val;
            else if (var == "croptofit") cropToFit = (integer)val;
            else if (var == "texturewidth") textureWidth = (integer)val;
            else if (var == "textureheight") textureHeight = (integer)val;
            else if (var == "texturesides") textureSides = llParseString2List(val, ",", "");

            // New variables from getConfig function
            else if (var == "duration") DURATION = (float)val;
            else if (var == "maxduration") MAX_DURATION = (float)val;
            else if (var == "maxprims") MAX_PRIMS = (integer)val;
            else if (var == "renewable") RENEWABLE = strToBoolean(val);
            else if (var == "expirereminder") EXPIRE_REMINDER = (float)val;
            else if (var == "expiregrace") EXPIRE_GRACE = (float)val;
        }
        i++;
    }
    while (i < count);
}

string cropText(string in, string fontname, integer fontsize,integer width)
{
    if(!cropToFit) return in;
    integer i;
    integer trimmed = FALSE;
    string suffix="";

    for(;llStringLength(in)>0;in=llGetSubString(in,0,-2)) {
        if(trimmed) suffix="...";
        vector extents = osGetDrawStringSize("vector",in+suffix,fontname,fontsize);

        if(extents.x<=width) {
                return in+suffix;
        }

        trimmed = TRUE;
    }

    return "";
}

drawText(string text)
{
    llSetText("",<1,0,0>, 1.0);
    string commandList = "";
    integer x = margin;
    integer y = margin;
    integer drawWidth = textureWidth - 2*margin;
    integer drawHeight = textureHeight - 2*margin;
    vector extents;
    extents = osGetDrawStringSize("vector",text,fontName,fontSize);
    if(extents.x > drawWidth)
    {
        if(cropToFit)
        {
            text = cropText(text, fontName, fontSize, drawWidth);
        } else {
            fontSize = (integer)(fontSize * drawWidth / extents.x);
        }
    } else {
        x += (integer)((drawWidth - extents.x) / 2);
    }
    extents = osGetDrawStringSize("vector",text,fontName,fontSize);
//    extents = osGetDrawStringSize("vector",text,fontName,fontSize);
//    if(extents.y > drawHeight)
//    {
//        textureHeight = (integer)extents.y + 2*margin;
//    } else {
        y += (integer)((drawHeight - extents.y) / 2);
//    }
    commandList = osSetPenColor(commandList, textColor);
    commandList = osSetFontName(commandList, fontName);
    commandList = osSetFontSize(commandList, fontSize);
    commandList = osMovePen(commandList, x, y);
    commandList = osDrawText(commandList, text);

    integer alpha = 256;
    if(backgroundColor == "transparent")
    {
        alpha = 0;
        //otherTexture = TEXTURE_TRANSPARENT;
    }
    integer i = 0;
    do
    {
        integer face=llList2Integer(textureSides, i);
        osSetDynamicTextureDataBlendFace("", "vector", commandList, "width:"+(string)textureWidth+",height:"+(string)textureHeight+",bgcolor:" + backgroundColor + ",alpha:"+alpha, FALSE, 2, 0, 255, face);
        i++;
    }
    while (i < llGetListLength(textureSides));
}

setTexture(string texture, list faces)
{
    integer i = 0;
    do
    {
        integer face=llList2Integer(faces, i);
        llSetTexture(texture,face);
        i++;
    }
    while (i < llGetListLength(faces));
}
setTexture(string texture, integer face)
{
        llSetTexture(texture,face);
}

string unTrailFloat(float value)
{
    string str = (string)value;
    integer len = llStringLength(str);
    while (len > 1 && llGetSubString(str, len - 1, len - 1) == "0")
    {
        len--;
    }
    if (len > 1 && llGetSubString(str, len - 1, len - 1) == ".")
    {
        len--;
    }
    return llStringTrim(llGetSubString(str, 0, len - 1), STRING_TRIM);
}

string unTrailVector(vector v)
{
    return "<" + unTrailFloat(v.x) + "," + unTrailFloat(v.y) +","+ unTrailFloat(v.z) + ">";
}

default
{
    state_entry()
    {
        parcelPos = llGetPos() + parcelDistance * llGetRot();
        parcelArea = llList2Integer(llGetParcelDetails(parcelPos, [PARCEL_DETAILS_AREA]),0);
        checkValidPosition();

        getConfig();

        llSetScale(SIZE_LEASED);
        setTexture(texture_expired,textureSides);
        if(isRented()) {
            llWhisper( 0, rentalInfo() );
            state leased;
        }
        else if(configured) {
            llWhisper( 0, rentalConditions() );
            state unleased;
        }
        // if(firstLaunch)
        // {
        //     firstLaunch = FALSE;
        //     statusUpdate("Activating...");
        //     if (MY_STATE == 0)
        //     state unleased;
        //     else if (MY_STATE == 1)
        //     state leased;
        // }
        llOwnerSay("Click this rental box to activate after configuring the DESCRIPTION.");
        llSetText("DISABLED",<0,0,0>, 1.0);
    }

    touch_start(integer total_number)
    {
        touchedKey = llDetectedKey(0);
        touchStarted=llGetTime();

        if (touchedKey == llGetOwner())
        {
            statusUpdate("Activating...");
            getConfig();
            if (MY_STATE == 0)
                state unleased;
            else if (MY_STATE == 1)
                state leased;
        }
    }

    on_rez(integer start_param)
    {
        debug("rez (from default)");
        state waiting;
    }

    changed(integer change)
    {
        if(change & CHANGED_LINK)
        {
            debug("CHANGED_LINK (from default)");
            state waiting;
        } else if (change & CHANGED_INVENTORY) {
            reloadConfig();
        }
    }
}

state unleased
{
    state_entry()
    {
        debug("state unleased");
        getConfig();
        if (MY_STATE !=0 || DURATION == 0)
        {
            debug("MY_STATE:" + (string) MY_STATE);
            debug("DURATION:" + (string) DURATION);
            debug("RENEWABLE:" + (string) RENEWABLE);
            llOwnerSay("Returning to default. Data is not correct.");
            state default;
        }

        llSetScale(SIZE_UNLEASED);

        //Blank texture
        setTexture(TEXTURE_BLANK,textureSides);

        setTexture(texture_unleased,textureSides);
        //llOwnerSay("Lease script is unleased");
        llSetText("",<1,0,0>, 1.0);
        reclaimParcel();
        llWhisper(0,"Ready for rental");
    }

    listen(integer channel, string name, key id, string message)
    {
        dialogActiveFlag = FALSE;
        llSetTimerEvent(0);
        llListenRemove(listener);

        getConfig();

        if (message == "Yes")
        {
            llInstantMessage(touchedKey,"Thanks for claiming this spot! Please wait a few moments...");
            MY_STATE = 1;
            LEASER = llKey2Name(touchedKey);
            string shortName = llStringTrim(strReplace( llList2String(llParseStringKeepNulls(LEASER,["@"],[]), 0), ".", " "), STRING_TRIM);
            LEASERID = touchedKey;
            LEASED_UNTIL = llGetUnixTime() + (integer) (DAYSEC * DURATION);
            debug("Remaining time:" +  secondsToHumanFormat(llGetUnixTime()-LEASED_UNTIL));

            SENT_WARNING = FALSE;
            save_data();
            llInstantMessage(llGetOwner(), "NEW CLAIM -" +  get_rentalbox_info());
            list rules =[
                PARCEL_DETAILS_NAME, shortName + "'s land",
                PARCEL_DETAILS_DESC, LEASER + "'s land; "
                    + parcelArea + " sqm; "
                    + MAX_PRIMS + " prims allowed.",
                PARCEL_DETAILS_OWNER, LEASERID,
                PARCEL_DETAILS_GROUP, NULL_KEY,
                PARCEL_DETAILS_CLAIMDATE, 0];
            osSetParcelDetails(parcelPos, rules);
            llSetText("",<1,0,0>, 1.0);
            llInstantMessage(LEASERID,"Your parcel is ready.\n"
            + get_rentalbox_url() + "\n" + "Please join the group to receive status updates.");
            osInviteToGroup(LEASERID);
            state leased;
        }
    }

    touch_start(integer total_number)
    {
        touchedKey = llDetectedKey(0);
        touchStarted=llGetTime();
    }

    touch_end(integer index)
    {
        touchedKey = llDetectedKey(0);

        // float touchElapsed = llGetTime() - touchStarted;
        if (touchedKey == llGetOwner() && llGetTime() - touchStarted > 2)
        {
            llOwnerSay("/me position check forced by long click");
            state waiting;
        }
        else
        {
            if(touchedKey == llGetOwner()) checkValidPosition();

            debug("touch event in unleased");
            getConfig();
            llInstantMessage(touchedKey, rentalConditions() );
            // llInstantMessage(touchedKey, "Claim Info");
            //
            // llInstantMessage(touchedKey, "Available for "  + (string)DURATION + " days ");
            // llInstantMessage(touchedKey, "Max Lease Length: " + (string)MAX_DURATION + " days");
            // llInstantMessage(touchedKey, "Max Prims: " + (string)MAX_PRIMS);
            //
            // if(llGetInventoryNumber(INVENTORY_NOTECARD) > 0 ) {
            //     llGiveInventory(touchedKey,llGetInventoryName(INVENTORY_NOTECARD,0));
            //     llInstantMessage(touchedKey, "Please read the covenant before renting");
            // }
            dialog();
        }
    }

        // touch_end(integer num){
        //     key touchedKey = llDetectedKey(0);
        //     // vector point = llDetectedTouchST(0);
        //     // integer face = llDetectedTouchFace(0);
        //     // integer link = llDetectedLinkNumber(0);
        //
        //     if (link != llGetLinkNumber()) return;
        //     if (point == TOUCH_INVALID_TEXCOORD) return;
        //     if (activeSide != ALL_SIDES && llListFindList(ACTIVE_SIDES, (string)face) == -1) return;
        //
        //     if (touchedKey == llGetOwner())
        //     {
        //         float touchElapsed = llGetTime() - touchStarted;
        //         if(touchElapsed > 2 && sourceType=="url") {
        //             llOwnerSay("/me reload forced by long click");
        //             state default;
        //         }
        //     }
        //
        //     integer ok = action (getCellClicked(point), touchedKey);
        // }

    // clear out the channel listener, the menu timed out
    timer()
    {
        dialogActiveFlag = FALSE;
        llListenRemove(listener);
    }
    on_rez(integer start_param)
    {
        debug("rez (from unleased)");
        state waiting;
    }
    changed(integer change)
    {
        if(change & CHANGED_LINK)
        {
            debug("CHANGED_LINK (from unleased)");
            state waiting;
        } else if (change & CHANGED_REGION_START) {
            // llResetScript();
        } else if (change & CHANGED_INVENTORY) {
            reloadConfig();
        } else {
            vector currentPos = llGetPos() + parcelDistance * llGetRot();
            if(currentPos != parcelPos)
            {
                debug("Position changed (from unleased)");
                state waiting;
            }
        }
    }
}

state leased
{
    state_entry()
    {
        setTexture(texture_busy,textureSides);
        debug("Leased mode");
        debug((string)llGetUnixTime());

        getConfig();
        if (MY_STATE != 1 || DURATION == 0 || LEASER == "")
        {
            debug("MY_STATE:" + (string) MY_STATE);
            debug("DURATION:" + (string) DURATION);
            debug("LEASER:" + (string) LEASER);

            MY_STATE = 0;
            save_data();
            llOwnerSay("Returning to unleased. Data was not correct.");
            state unleased;
        }
        llSetScale(SIZE_LEASED);
        string parcelName = (string)llGetParcelDetails(parcelPos, [PARCEL_DETAILS_NAME]);
        drawText(parcelName);

        debug("Remaining time:" +  secondsToHumanFormat(llGetUnixTime()-LEASED_UNTIL));

        llSetTimerEvent(1); //check now
        statusUpdate("Ready");
    }

    listen(integer channel, string name, key id, string message)
    {
        debug("listen event in leased");
        dialogActiveFlag = FALSE;
        if (message == "Yes")
        {
            getConfig();
            if (MY_STATE != 1 || DURATION == 0 || LEASER == "")
            {
                debug("MY_STATE:" + (string) MY_STATE);
                debug("DURATION:" + (string) DURATION);
                debug("LEASER:" + (string) LEASER);

                MY_STATE = 0;
                save_data();
                statusUpdate("Returning to unleased. Data is not correct.");
                state unleased;
            }
            else if (RENEWABLE)
            {
                integer timeleft = LEASED_UNTIL - llGetUnixTime();

                debug("Remaining time:" +  secondsToHumanFormat(llGetUnixTime()-LEASED_UNTIL));
                debug("DAYSEC:" + (string) DAYSEC);
                debug("timeleft:" + (string) timeleft);
                debug("MAX_DURATION:" + (string) MAX_DURATION);

                if (DAYSEC + timeleft > MAX_DURATION * DAYSEC)
                {
                    llInstantMessage(LEASERID,"Sorry, you can not claim more than the max time");
                }
                else
                {
                    debug("Leased");
                    SENT_WARNING = FALSE;
                    LEASED_UNTIL += (integer) DURATION;
                    // debug("Leased until " + (string)LEASED_UNTIL );
                    save_data();
                    llSetScale(SIZE_LEASED);
                    //setTexture(texture_leased,textureSides);
                    statusUpdate("Renewed" + get_rentalbox_info());
                    // llInstantMessage(llGetOwner(), "Renewed: " + get_rentalbox_info());
                }
            }
            else
            {
                llInstantMessage(LEASERID,"Sorry you can not renew at this time.");
            }
        } else if (message == "Abandon") {
            key FORMERLEASERID=LEASERID;
            reclaimParcel();
            llInstantMessage(FORMERLEASERID, "You abandonned your land, it has been reset to the estate owner. Please cleanup the parcel. Objects owned by you on the parcel will be returned soon.");
            MY_STATE = 0;
            save_data();
            state unleased;
        }
    }

    timer()
    {
        if (dialogActiveFlag)
        {
            dialogActiveFlag = FALSE;
            llListenRemove(listener);
            return;
        }


        if(!DEBUG)
            llSetTimerEvent(900); //15 minute checks
        else
            llSetTimerEvent(30); // 30  second checks for

        debug("timer event in leased");

        getConfig();

        if (MY_STATE != 1 || DURATION == 0 || LEASER == "")
        {
            debug("MY_STATE:" + (string) MY_STATE);
            debug("DURATION:" + (string) DURATION);
            debug("LEASER:" + (string) LEASER);

            MY_STATE = 0;
            save_data();
            statusUpdate("Returning to unleased. Data is not correct.");
            state unleased;
        }

        integer count = llGetParcelPrimCount(parcelPos,PARCEL_COUNT_TOTAL, FALSE);

        if (count -1  > MAX_PRIMS && !SENT_PRIMWARNING) // no need to countthe sign, too.
        {
            llInstantMessage(LEASERID, get_rentalbox_info() + " There are supposed to be no more than " + (string)MAX_PRIMS
                + " prims rezzed, yet there are "
                +(string) count + " prims rezzed on this parcel. Plese remove the excess.");
            llInstantMessage(llGetOwner(),  get_rentalbox_info() + " There are supposed to be no more than " + (string)MAX_PRIMS
                + " prims rezzed, yet there are "
                +(string) count + " prims rezzed on this parcel, warning sent to " + LEASER );
            SENT_PRIMWARNING = TRUE;
        } else {
            SENT_PRIMWARNING = FALSE;
        }



        debug("Remaining time:" +  secondsToHumanFormat(llGetUnixTime()-LEASED_UNTIL));

        if (RENEWABLE)
        {

            debug( (string) LEASED_UNTIL + " > " + (string) llGetUnixTime());

            debug( "EXPIRE_REMINDER * DAYSEC " + (string) (EXPIRE_REMINDER * DAYSEC));

            if (LEASED_UNTIL > llGetUnixTime() && LEASED_UNTIL - llGetUnixTime() < EXPIRE_REMINDER * DAYSEC)
            {
                debug("Claim must be renewed");
                setTexture(texture_expired,textureSides);
                llSetText("Claim must be renewed!",<1,0,0>, 1.0);
            }
            else if (LEASED_UNTIL < llGetUnixTime()  && llGetUnixTime() - LEASED_UNTIL < EXPIRE_GRACE * DAYSEC)
            {
                if (!SENT_WARNING)
                {
                    debug("sending warn");
                    llInstantMessage(LEASERID, "Your claim needs to be renewed, please go to your parcel " + get_rentalbox_url() + " and touch the sign to claim it again! - " + get_rentalbox_info());
                    llInstantMessage(llGetOwner(), "CLAIM DUE - " + get_rentalbox_info());
                    SENT_WARNING = TRUE;
                    save_data();
                }
                setTexture(texture_expired,textureSides);
                llSetText("CLAIM IS PAST DUE!",<1,0,0>, 1.0);
            }
            else if (LEASED_UNTIL < llGetUnixTime())
            {
                debug("expired");
                //llInstantMessage(LEASERID, "Your claim has expired. Please clean up the space or contact the space owner.");
                //vector signPos=llGetPos();
                //llSetPos(parcelPos);
                //llReturnObjectsByOwner(LEASERID,  OBJECT_RETURN_PARCEL_OWNER);
                llInstantMessage(LEASERID, "Your claim has expired. Please cleanup the parcel. Objects owned by you on the parcel will be returned soon.");
                llInstantMessage(llGetOwner(), "CLAIM EXPIRED: CLEANUP! -  " + get_rentalbox_info());
                reclaimParcel();
                MY_STATE = 0;
                save_data();
                state unleased;
            }
        }
        else if (LEASED_UNTIL < llGetUnixTime())
        {
            llInstantMessage(llGetOwner(), "CLAIM EXPIRED: CLEANUP! -  " + get_rentalbox_info());
            debug("TIME EXPIRED. RETURNING TO DEFAULT");
            reclaimParcel();
            MY_STATE = 0;
            save_data();
            state unleased;
            //state default;
        }
    }

    touch_start(integer total_number)
    {
        touchedKey = llDetectedKey(0);
        touchStarted=llGetTime();
        debug("touch event in leased");

        if(touchedKey == llGetOwner()) checkValidPosition();

        getConfig();

        if (MY_STATE != 1 || DURATION == 0 || LEASER == "" )
        {
            debug("MY_STATE:" + (string) MY_STATE);
            debug("DURATION:" + (string) DURATION);
            debug("LEASER:" + (string) LEASER);

            MY_STATE = 0;
            save_data();
            statusUpdate("Returning to unleased. Data is not correct.");
            state unleased;
        }


        if(LEASED_UNTIL < llGetUnixTime())
        statusUpdate("Claim due since " + secondsToHumanFormat(llGetUnixTime()-LEASED_UNTIL));
        else
        llWhisper(0, rentalInfo());

        // same as money
        if (touchedKey == LEASERID && RENEWABLE)
        {
            string parcelName = (string)llGetParcelDetails(parcelPos, [PARCEL_DETAILS_NAME]);
            drawText(parcelName);

            LEASED_UNTIL = llGetUnixTime() + (integer) (DAYSEC * DURATION);
            llInstantMessage(LEASERID, "Renewed until " + Unix2PST_PDT(LEASED_UNTIL));
            dialog();
        // } else {
        //     llInstantMessage(touchedKey, "Leased until " + Unix2PST_PDT(LEASED_UNTIL));
        }

        // same as money
        if (touchedKey == LEASERID && !RENEWABLE)
        {
             llInstantMessage(LEASERID,"The parcel cannot be claimed again");
        }
    }
    on_rez(integer start_param)
    {
        debug("rez (from leased)");
        state waiting;
    }
    changed(integer change)
    {
        if(change & CHANGED_LINK)
        {
            debug("CHANGED_LINK (from leased)");
            state waiting;
        } else if (change & CHANGED_REGION_START) {
            // llResetScript();
        } else if (change & CHANGED_INVENTORY) {
            reloadConfig();
        } else {
            vector currentPos = llGetPos() + parcelDistance * llGetRot();
            if(currentPos != parcelPos)
            {
                debug("Position changed (from unleased)");
                state waiting;
            }
        }
    }
}

state waiting
{
    state_entry()
    {
        debug("entering wait state");
        integer positionConfirmed = TRUE;
        positionConfirmed = FALSE;
        llSetLinkPrimitiveParamsFast(checkerLink, [
        PRIM_POS_LOCAL, parcelDistance,
        PRIM_COLOR, ALL_SIDES, <1,1,0>, 0.75,
        PRIM_GLOW, ALL_SIDES, 0.05,
        PRIM_SIZE, <0.25,0.25,5>
        ]);
        integer channel = llCeil(llFrand(1000000)) + 100000 * -1; // negative channel # cannot be typed
        listener = llListen(channel,"","","");
        llDialog(llGetOwner(),
        "WARNING:\n"
        + "Place the vendor OUTSIDE the rented parcel, but make sure the YELLOW MARK stays INSIDE the rented parcel. Then click the Checked button.",
        ["Checked"],
        channel);
        //
    }
    listen(integer channel, string name, key id, string message)
    {
        if(id == llGetOwner() && message == "Checked")
        {
            debug("verified");
            llSetLinkPrimitiveParamsFast(checkerLink, [
            PRIM_POS_LOCAL, <0,0,0>,
            PRIM_COLOR, ALL_SIDES, <1,1,1>, 0.0,
            PRIM_GLOW, ALL_SIDES, 0.00,
            PRIM_SIZE, <0.01,0.01,0.1>
            ]);
            llSleep(5);
            firstLaunch = FALSE;
            signPos = llGetPos();
            state default;
        }
    }
    on_rez(integer start_param)
    {
        debug("rez (from waiting)");
        state waiting;
    }
    changed(integer change)
    {
        if(change & CHANGED_LINK) {
            debug("CHANGED_LINK (from waiting)");
            state waiting;
        } else if (change & CHANGED_INVENTORY) {
            reloadConfig();
        }
    }
}
