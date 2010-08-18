CREATE TABLE printers_pages(
         timestamp TIMESTAMP, 
         job INT, 
         printer VARCHAR(255),     
         pages INT
        );
CREATE INDEX printers_pages_job_i on printers_pages(timestamp);

