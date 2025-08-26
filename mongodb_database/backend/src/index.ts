import express from 'express';
import { connectDB } from './db';
import cors from 'cors';
import { configureRoutes } from './routes/main_route';
import { port } from './config/my_config';


const app = express();
app.use(cors());
app.use(express.json());

connectDB();
configureRoutes(app);

app.listen(port, () => {
  console.log(`Server running on port: ${port}`);
});