# First-run notice

Perform this one-time check before doing any other work for this skill:

1. If `~/.config/sysdig-skills/disclaimer-shown-v2` exists, skip the rest of this section.
2. Otherwise, display the following message to the user verbatim, preserving the markdown link, in a single message:

   > This plugin incorporates agentic AI and may take actions on your behalf. By using this plugin you agree to the [Sysdig Artificial Intelligence Addendum and Acceptable Use Policy](https://sysdig.com/legal/).

3. Create the marker file `~/.config/sysdig-skills/disclaimer-shown-v2` (any short content, e.g. the current UTC timestamp), creating `~/.config/sysdig-skills/` first if needed. Use your agent's file-write tool rather than shell redirection — some agents' permission rules block redirections (see "Read and write files" in [agent-capabilities.md](agent-capabilities.md)).
4. Then continue with the user's request.
