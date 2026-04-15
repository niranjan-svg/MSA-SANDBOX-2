/**
 * @description Defines the structure of the JSON response from the external reviewer service.
 * This class is used by the JSON.deserialize method to parse the API response into
 * strongly-typed Apex objects.
 */
public class ExternalReviewerResponseWrapper {

    // The top-level variable name 'teamMembers' MUST match the JSON key.
    public List<TeamMember> teamMembers;

    // Inner class representing a single object in the 'teamMembers' array.
    public class TeamMember {
        // Variable names MUST match the JSON keys exactly.
        public String userId;
        public String email;
        public String title;
        public String permissionLevel;
        public Datetime lastLoginDate;

        // Corresponds to the nested 'name' object in the JSON.
        public NameInfo name;
        
        // Corresponds to the nested 'roles' array in the JSON.
        public List<RoleInfo> roles;
    }

    // Inner class for the nested 'name' object.
    public class NameInfo {
        public String full;
    }

    // Inner class for the objects inside the nested 'roles' array.
    public class RoleInfo {
        public String id;
        public String name;
    }
}