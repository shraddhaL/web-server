pipeline {
     agent any

    stages{ 
	    stage('Clone repository') {
			 steps {	       
				git 'https://github.com/shraddhaL/web-server.git'
			   }
		 }
	    stage('terraform init') {
	      steps {
                    sh 'terraform init'
	      }
        }
	   
	      stage('terraform plan') {
	      steps {
                    sh 'terraform plan' 
	      }
        }
	 
	      stage('terraform apply tomcat_container') {
	      steps {
                    sh 'terraform apply -auto-approve=true '
	      }
        }
	  
    }
	
post{
		always{
				 sh 'terraform destroy --auto-approve'
			 }
		}
	}
	
}
