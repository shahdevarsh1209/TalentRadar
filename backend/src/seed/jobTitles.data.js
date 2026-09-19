'use strict';

/**
 * Seed data for the job-title master.
 *
 * `code` is the stable identity that profiles store. `aliases` exist so a search
 * for "SDE", "programmer" or "accounts" finds the canonical title — this is what
 * keeps candidate titles and recruiter hiring profiles on one vocabulary.
 * `popularity` (0-100) orders suggestions before any text score is applied.
 */

const JOB_TITLES = [
  // Technology - engineering
  { code: 'JT_001', name: 'Software Engineer', category: 'Technology', popularity: 98, aliases: ['Software Developer', 'SDE', 'Software Programmer', 'Programmer', 'Dev Engineer'] },
  { code: 'JT_002', name: 'Software Developer', category: 'Technology', popularity: 95, aliases: ['Application Developer', 'Software Engineer', 'Developer'] },
  { code: 'JT_003', name: 'Senior Software Engineer', category: 'Technology', popularity: 88, aliases: ['Senior SDE', 'SDE II', 'Senior Developer'] },
  { code: 'JT_004', name: 'Flutter Developer', category: 'Technology', popularity: 86, aliases: ['Flutter Engineer', 'Dart Developer', 'Cross Platform Developer'] },
  { code: 'JT_005', name: 'React Developer', category: 'Technology', popularity: 90, aliases: ['ReactJS Developer', 'React.js Engineer', 'Frontend React Developer'] },
  { code: 'JT_006', name: 'React Native Developer', category: 'Technology', popularity: 78, aliases: ['RN Developer', 'React Native Engineer'] },
  { code: 'JT_007', name: 'Node.js Developer', category: 'Technology', popularity: 85, aliases: ['NodeJS Developer', 'Node Engineer', 'Backend Node Developer'] },
  { code: 'JT_008', name: 'Full Stack Developer', category: 'Technology', popularity: 94, aliases: ['Fullstack Engineer', 'MERN Developer', 'MEAN Developer', 'Full-Stack Developer'] },
  { code: 'JT_009', name: 'Frontend Developer', category: 'Technology', popularity: 92, aliases: ['Front End Developer', 'UI Developer', 'Frontend Engineer'] },
  { code: 'JT_010', name: 'Backend Developer', category: 'Technology', popularity: 91, aliases: ['Back End Developer', 'Backend Engineer', 'Server Side Developer'] },
  { code: 'JT_011', name: 'Web Developer', category: 'Technology', popularity: 87, aliases: ['Website Developer', 'Web Programmer'] },
  { code: 'JT_012', name: 'Android Developer', category: 'Technology', popularity: 82, aliases: ['Android Engineer', 'Kotlin Developer', 'Mobile Developer Android'] },
  { code: 'JT_013', name: 'iOS Developer', category: 'Technology', popularity: 75, aliases: ['Swift Developer', 'iOS Engineer'] },
  { code: 'JT_014', name: 'Mobile Application Developer', category: 'Technology', popularity: 77, aliases: ['Mobile App Developer', 'App Developer'] },
  { code: 'JT_015', name: 'Java Developer', category: 'Technology', popularity: 89, aliases: ['Java Engineer', 'Core Java Developer', 'Spring Boot Developer'] },
  { code: 'JT_016', name: 'Python Developer', category: 'Technology', popularity: 88, aliases: ['Python Engineer', 'Django Developer', 'FastAPI Developer'] },
  { code: 'JT_017', name: '.NET Developer', category: 'Technology', popularity: 76, aliases: ['Dot Net Developer', 'C# Developer', 'ASP.NET Developer'] },
  { code: 'JT_018', name: 'PHP Developer', category: 'Technology', popularity: 70, aliases: ['Laravel Developer', 'WordPress Developer'] },
  { code: 'JT_019', name: 'Golang Developer', category: 'Technology', popularity: 62, aliases: ['Go Developer', 'Go Engineer'] },
  { code: 'JT_020', name: 'DevOps Engineer', category: 'Technology', popularity: 84, aliases: ['Site Reliability Engineer', 'SRE', 'Platform Engineer', 'Infrastructure Engineer'] },
  { code: 'JT_021', name: 'Cloud Engineer', category: 'Technology', popularity: 79, aliases: ['AWS Engineer', 'Azure Engineer', 'GCP Engineer', 'Cloud Architect'] },
  { code: 'JT_022', name: 'QA Engineer', category: 'Technology', popularity: 83, aliases: ['Quality Analyst', 'Software Tester', 'Test Engineer', 'QA Analyst'] },
  { code: 'JT_023', name: 'Automation Test Engineer', category: 'Technology', popularity: 74, aliases: ['SDET', 'Selenium Tester', 'Automation QA'] },
  { code: 'JT_024', name: 'Software Tester', category: 'Technology', popularity: 72, aliases: ['Manual Tester', 'QA Tester'] },
  { code: 'JT_025', name: 'Software Architect', category: 'Technology', popularity: 60, aliases: ['Solution Architect', 'Technical Architect'] },
  { code: 'JT_026', name: 'Software Consultant', category: 'Technology', popularity: 58, aliases: ['Technology Consultant', 'IT Consultant'] },
  { code: 'JT_027', name: 'Technical Lead', category: 'Technology', popularity: 73, aliases: ['Tech Lead', 'Team Lead Engineering', 'Engineering Lead'] },
  { code: 'JT_028', name: 'Engineering Manager', category: 'Technology', popularity: 64, aliases: ['EM', 'Development Manager'] },
  { code: 'JT_029', name: 'Database Administrator', category: 'Technology', popularity: 61, aliases: ['DBA', 'SQL Administrator', 'Database Engineer'] },
  { code: 'JT_030', name: 'Cybersecurity Analyst', category: 'Technology', popularity: 66, aliases: ['Security Analyst', 'Information Security Analyst', 'SOC Analyst'] },
  { code: 'JT_031', name: 'Network Engineer', category: 'Technology', popularity: 65, aliases: ['Network Administrator', 'Network Support Engineer'] },
  { code: 'JT_032', name: 'System Administrator', category: 'Technology', popularity: 63, aliases: ['Sysadmin', 'Linux Administrator', 'Windows Administrator'] },
  { code: 'JT_033', name: 'Embedded Engineer', category: 'Technology', popularity: 55, aliases: ['Embedded Systems Engineer', 'Firmware Engineer'] },
  { code: 'JT_034', name: 'Blockchain Developer', category: 'Technology', popularity: 48, aliases: ['Web3 Developer', 'Solidity Developer'] },
  { code: 'JT_035', name: 'Game Developer', category: 'Technology', popularity: 47, aliases: ['Unity Developer', 'Unreal Developer'] },

  // Support and implementation
  { code: 'JT_040', name: 'Software Support Executive', category: 'Support', popularity: 85, aliases: ['Software Support Engineer', 'Application Support Executive', 'Product Support Executive'] },
  { code: 'JT_041', name: 'Technical Support Engineer', category: 'Support', popularity: 84, aliases: ['Tech Support Engineer', 'IT Support Engineer', 'Helpdesk Engineer'] },
  { code: 'JT_042', name: 'Customer Support Executive', category: 'Support', popularity: 93, aliases: ['Customer Service Executive', 'Support Executive', 'CSE'] },
  { code: 'JT_043', name: 'Customer Success Executive', category: 'Support', popularity: 80, aliases: ['Customer Success Associate', 'CSM Executive'] },
  { code: 'JT_044', name: 'Customer Success Manager', category: 'Support', popularity: 70, aliases: ['CSM', 'Client Success Manager'] },
  { code: 'JT_045', name: 'Tele-support Associate', category: 'Support', popularity: 74, aliases: ['Telecaller', 'Voice Process Executive', 'Telesupport Executive'] },
  { code: 'JT_046', name: 'Support Trainee', category: 'Support', popularity: 68, aliases: ['Support Intern', 'Trainee Support Executive'] },
  { code: 'JT_047', name: 'Service Desk Analyst', category: 'Support', popularity: 62, aliases: ['Helpdesk Analyst', 'IT Helpdesk Executive'] },
  { code: 'JT_048', name: 'ERP Support Executive', category: 'Support', popularity: 66, aliases: ['ERP Support Engineer', 'SAP Support Executive'] },
  { code: 'JT_049', name: 'ERP Functional Consultant', category: 'Technology', popularity: 64, aliases: ['SAP Functional Consultant', 'ERP Consultant', 'Functional Consultant'] },
  { code: 'JT_050', name: 'ERP Implementation Executive', category: 'Technology', popularity: 58, aliases: ['ERP Implementation Consultant', 'Implementation Executive'] },
  { code: 'JT_051', name: 'ERP Technical Consultant', category: 'Technology', popularity: 54, aliases: ['SAP ABAP Consultant', 'ERP Developer'] },
  { code: 'JT_052', name: 'Salesforce Developer', category: 'Technology', popularity: 61, aliases: ['SFDC Developer', 'Apex Developer'] },
  { code: 'JT_053', name: 'Salesforce Administrator', category: 'Technology', popularity: 56, aliases: ['SFDC Admin', 'Salesforce Admin'] },

  // Data and AI
  { code: 'JT_060', name: 'Data Analyst', category: 'Data & AI', popularity: 92, aliases: ['Business Data Analyst', 'Analytics Executive', 'Reporting Analyst'] },
  { code: 'JT_061', name: 'Data Scientist', category: 'Data & AI', popularity: 85, aliases: ['ML Scientist', 'Applied Scientist'] },
  { code: 'JT_062', name: 'Data Engineer', category: 'Data & AI', popularity: 82, aliases: ['ETL Developer', 'Big Data Engineer', 'Pipeline Engineer'] },
  { code: 'JT_063', name: 'Machine Learning Engineer', category: 'Data & AI', popularity: 80, aliases: ['ML Engineer', 'AI Engineer', 'Deep Learning Engineer'] },
  { code: 'JT_064', name: 'Business Intelligence Analyst', category: 'Data & AI', popularity: 70, aliases: ['BI Analyst', 'Power BI Developer', 'Tableau Developer'] },
  { code: 'JT_065', name: 'MIS Executive', category: 'Data & AI', popularity: 72, aliases: ['MIS Analyst', 'MIS Officer'] },

  // Design
  { code: 'JT_070', name: 'UI/UX Designer', category: 'Design', popularity: 91, aliases: ['Product Designer', 'UX Designer', 'UI Designer', 'Interaction Designer'] },
  { code: 'JT_071', name: 'Graphic Designer', category: 'Design', popularity: 88, aliases: ['Visual Designer', 'Creative Designer'] },
  { code: 'JT_072', name: 'UX Researcher', category: 'Design', popularity: 63, aliases: ['User Researcher', 'Design Researcher'] },
  { code: 'JT_073', name: 'Motion Graphics Designer', category: 'Design', popularity: 55, aliases: ['Animator', 'Video Motion Designer'] },
  { code: 'JT_074', name: 'Video Editor', category: 'Design', popularity: 68, aliases: ['Video Producer', 'Post Production Editor'] },
  { code: 'JT_075', name: 'Product Designer', category: 'Design', popularity: 74, aliases: ['Digital Product Designer'] },

  // Marketing
  { code: 'JT_080', name: 'Digital Marketing Executive', category: 'Marketing', popularity: 90, aliases: ['Digital Marketer', 'Online Marketing Executive', 'Performance Marketing Executive'] },
  { code: 'JT_081', name: 'Digital Marketing Manager', category: 'Marketing', popularity: 72, aliases: ['Growth Marketing Manager'] },
  { code: 'JT_082', name: 'SEO Executive', category: 'Marketing', popularity: 78, aliases: ['SEO Analyst', 'Search Engine Optimisation Executive'] },
  { code: 'JT_083', name: 'Social Media Executive', category: 'Marketing', popularity: 80, aliases: ['Social Media Manager', 'Community Manager'] },
  { code: 'JT_084', name: 'Content Writer', category: 'Marketing', popularity: 82, aliases: ['Copywriter', 'Content Executive', 'Content Specialist'] },
  { code: 'JT_085', name: 'Brand Manager', category: 'Marketing', popularity: 58, aliases: ['Brand Executive'] },
  { code: 'JT_086', name: 'Marketing Executive', category: 'Marketing', popularity: 84, aliases: ['Marketing Associate', 'Marketing Officer'] },
  { code: 'JT_087', name: 'Performance Marketing Specialist', category: 'Marketing', popularity: 62, aliases: ['Paid Ads Specialist', 'Google Ads Executive', 'Meta Ads Executive'] },

  // Sales and business
  { code: 'JT_090', name: 'Sales Executive', category: 'Sales', popularity: 95, aliases: ['Sales Associate', 'Sales Officer', 'Field Sales Executive'] },
  { code: 'JT_091', name: 'Business Development Executive', category: 'Sales', popularity: 93, aliases: ['BDE', 'Business Development Associate', 'BD Executive'] },
  { code: 'JT_092', name: 'Business Development Manager', category: 'Sales', popularity: 78, aliases: ['BDM', 'BD Manager'] },
  { code: 'JT_093', name: 'Inside Sales Executive', category: 'Sales', popularity: 76, aliases: ['Inside Sales Associate', 'Tele Sales Executive'] },
  { code: 'JT_094', name: 'Sales Manager', category: 'Sales', popularity: 80, aliases: ['Regional Sales Manager', 'Area Sales Manager'] },
  { code: 'JT_095', name: 'Key Account Manager', category: 'Sales', popularity: 64, aliases: ['Account Manager', 'Client Relationship Manager'] },
  { code: 'JT_096', name: 'Relationship Manager', category: 'Sales', popularity: 74, aliases: ['Customer Relationship Manager', 'RM'] },
  { code: 'JT_097', name: 'Business Analyst', category: 'Business', popularity: 86, aliases: ['BA', 'Functional Business Analyst', 'Systems Analyst'] },

  // Human resources
  { code: 'JT_100', name: 'HR Executive', category: 'Human Resources', popularity: 90, aliases: ['Human Resource Executive', 'HR Associate', 'HR Generalist'] },
  { code: 'JT_101', name: 'HR Manager', category: 'Human Resources', popularity: 78, aliases: ['Human Resource Manager', 'HR Business Partner', 'HRBP'] },
  { code: 'JT_102', name: 'Talent Acquisition Executive', category: 'Human Resources', popularity: 82, aliases: ['Recruiter', 'TA Executive', 'Recruitment Executive'] },
  { code: 'JT_103', name: 'Talent Acquisition Manager', category: 'Human Resources', popularity: 66, aliases: ['TA Manager', 'Recruitment Manager', 'Hiring Manager'] },
  { code: 'JT_104', name: 'HR Intern', category: 'Human Resources', popularity: 55, aliases: ['HR Trainee'] },
  { code: 'JT_105', name: 'Payroll Executive', category: 'Human Resources', popularity: 58, aliases: ['Payroll Officer', 'Compensation Executive'] },

  // Finance and accounts
  { code: 'JT_110', name: 'Accountant', category: 'Finance', popularity: 92, aliases: ['Accounts Professional', 'Staff Accountant', 'Junior Accountant'] },
  { code: 'JT_111', name: 'Senior Accountant', category: 'Finance', popularity: 76, aliases: ['Sr Accountant', 'Lead Accountant'] },
  { code: 'JT_112', name: 'Accounts Executive', category: 'Finance', popularity: 88, aliases: ['Accounts Assistant', 'Accounts Officer'] },
  { code: 'JT_113', name: 'Accounts Manager', category: 'Finance', popularity: 70, aliases: ['Manager Accounts', 'Finance Manager'] },
  { code: 'JT_114', name: 'Financial Analyst', category: 'Finance', popularity: 74, aliases: ['Finance Analyst', 'FP&A Analyst'] },
  { code: 'JT_115', name: 'Audit Executive', category: 'Finance', popularity: 60, aliases: ['Internal Auditor', 'Audit Associate'] },
  { code: 'JT_116', name: 'Chartered Accountant', category: 'Finance', popularity: 68, aliases: ['CA', 'Qualified CA'] },
  { code: 'JT_117', name: 'Tax Consultant', category: 'Finance', popularity: 54, aliases: ['GST Consultant', 'Taxation Executive'] },

  // Product, project and operations
  { code: 'JT_120', name: 'Project Manager', category: 'Management', popularity: 87, aliases: ['PM', 'Delivery Manager', 'Program Manager'] },
  { code: 'JT_121', name: 'Product Manager', category: 'Management', popularity: 83, aliases: ['Associate Product Manager', 'APM', 'Product Owner'] },
  { code: 'JT_122', name: 'Scrum Master', category: 'Management', popularity: 62, aliases: ['Agile Coach'] },
  { code: 'JT_123', name: 'Operations Executive', category: 'Operations', popularity: 85, aliases: ['Ops Executive', 'Operations Associate'] },
  { code: 'JT_124', name: 'Operations Manager', category: 'Operations', popularity: 74, aliases: ['Ops Manager'] },
  { code: 'JT_125', name: 'Supply Chain Executive', category: 'Operations', popularity: 62, aliases: ['Logistics Executive', 'SCM Executive'] },
  { code: 'JT_126', name: 'Warehouse Executive', category: 'Operations', popularity: 58, aliases: ['Store Executive', 'Inventory Executive'] },
  { code: 'JT_127', name: 'Procurement Executive', category: 'Operations', popularity: 56, aliases: ['Purchase Executive', 'Sourcing Executive'] },
  { code: 'JT_128', name: 'Admin Executive', category: 'Operations', popularity: 70, aliases: ['Administration Executive', 'Office Administrator', 'Back Office Executive'] },
  { code: 'JT_129', name: 'Data Entry Operator', category: 'Operations', popularity: 72, aliases: ['Data Entry Executive', 'DEO'] },

  // Core engineering and other sectors
  { code: 'JT_140', name: 'Mechanical Engineer', category: 'Core Engineering', popularity: 74, aliases: ['Design Engineer Mechanical', 'Production Engineer'] },
  { code: 'JT_141', name: 'Civil Engineer', category: 'Core Engineering', popularity: 72, aliases: ['Site Engineer', 'Structural Engineer'] },
  { code: 'JT_142', name: 'Electrical Engineer', category: 'Core Engineering', popularity: 70, aliases: ['Electrical Design Engineer'] },
  { code: 'JT_143', name: 'Production Supervisor', category: 'Core Engineering', popularity: 60, aliases: ['Shop Floor Supervisor', 'Manufacturing Supervisor'] },
  { code: 'JT_144', name: 'Quality Control Engineer', category: 'Core Engineering', popularity: 62, aliases: ['QC Engineer', 'Quality Inspector'] },
  { code: 'JT_150', name: 'Pharmacist', category: 'Healthcare', popularity: 58, aliases: ['Retail Pharmacist', 'Clinical Pharmacist'] },
  { code: 'JT_151', name: 'Staff Nurse', category: 'Healthcare', popularity: 62, aliases: ['Nurse', 'Registered Nurse'] },
  { code: 'JT_152', name: 'Medical Representative', category: 'Healthcare', popularity: 66, aliases: ['MR', 'Pharma Sales Executive'] },
  { code: 'JT_153', name: 'Lab Technician', category: 'Healthcare', popularity: 56, aliases: ['Laboratory Technician', 'Pathology Technician'] },
  { code: 'JT_160', name: 'Teacher', category: 'Education', popularity: 70, aliases: ['School Teacher', 'Subject Teacher', 'Faculty'] },
  { code: 'JT_161', name: 'Lecturer', category: 'Education', popularity: 56, aliases: ['Assistant Professor', 'College Faculty'] },
  { code: 'JT_162', name: 'Academic Counsellor', category: 'Education', popularity: 62, aliases: ['Education Counsellor', 'Admission Counsellor'] },
  { code: 'JT_163', name: 'Corporate Trainer', category: 'Education', popularity: 52, aliases: ['Soft Skills Trainer', 'Technical Trainer'] },
  { code: 'JT_170', name: 'Hotel Manager', category: 'Hospitality', popularity: 48, aliases: ['Front Office Manager'] },
  { code: 'JT_171', name: 'Chef', category: 'Hospitality', popularity: 52, aliases: ['Commis Chef', 'Sous Chef', 'Cook'] },
  { code: 'JT_172', name: 'Delivery Executive', category: 'Logistics', popularity: 74, aliases: ['Delivery Partner', 'Rider', 'Field Delivery Associate'] },
  { code: 'JT_173', name: 'Driver', category: 'Logistics', popularity: 64, aliases: ['Cab Driver', 'Commercial Driver'] },
  { code: 'JT_174', name: 'Security Officer', category: 'Facilities', popularity: 50, aliases: ['Security Guard', 'Security Supervisor'] },
  { code: 'JT_175', name: 'Retail Store Executive', category: 'Retail', popularity: 68, aliases: ['Store Executive Retail', 'Sales Associate Retail', 'Floor Executive'] },
  { code: 'JT_176', name: 'Cashier', category: 'Retail', popularity: 56, aliases: ['Billing Executive', 'Counter Executive'] },
  { code: 'JT_180', name: 'Legal Executive', category: 'Legal', popularity: 50, aliases: ['Legal Associate', 'Paralegal'] },
  { code: 'JT_181', name: 'Company Secretary', category: 'Legal', popularity: 44, aliases: ['CS', 'Compliance Officer'] },
  { code: 'JT_190', name: 'Intern', category: 'Entry Level', popularity: 66, aliases: ['Trainee', 'Graduate Trainee', 'Management Trainee'] },
  { code: 'JT_191', name: 'Fresher', category: 'Entry Level', popularity: 70, aliases: ['Entry Level Candidate', 'Graduate'] },
];

module.exports = JOB_TITLES;
