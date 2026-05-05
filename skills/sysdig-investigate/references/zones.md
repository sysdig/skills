# Sysdig Zones retrieval

## Zone fetch and display

Call `list_zones` to fetch at most 100 available zones names for this customer.

Present the list to the user of the 10 most significative ones. 
Zones with names containing prod, production, cloud provider regions names should be ranked first.
If the state contains a previously used environment, suggest it as the default.
