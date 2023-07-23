// Function to check and return expired objects
void checkAndReturnExpiredObjects()
{
    // Get the owner of the parcel
    key parcelOwner = llGetParcelOwner(llGetPos());

    // Get the list of objects owned by others in the parcel
    list otherObjects = llGetObjectsInSameRegion();
    integer numObjects = llGetListLength(otherObjects);

    for (integer i = 0; i < numObjects; i++)
    {
        key objKey = llList2Key(otherObjects, i);
        key objOwner = llGetObjectPermMask(objKey, MASK_OWNER);

        if (objOwner != parcelOwner) // Object is owned by someone else
        {
            // Return the object to its owner
            llReturnObjectsByOwner(objOwner);
        }
    }
}

default
{
    state_entry() {
    }
}
