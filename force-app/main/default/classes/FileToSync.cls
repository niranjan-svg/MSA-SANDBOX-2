/**
 * @description A standalone, public wrapper class to hold information about a file 
 * that needs to be downloaded. This is a shared data structure used by other classes.
 */
public class FileToSync {
    public String fileName { get; set; }
    public String downloadUrl { get; set; }
    public Id parentId { get; set; }

    // This constructor is used by the Form Sync job to create new instances
    public FileToSync(String name, String url, Id pId) {
        this.fileName = name;
        this.downloadUrl = url;
        this.parentId = pId;
    }
}