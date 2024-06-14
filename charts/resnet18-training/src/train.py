import os
import argparse

import torch
import torch.nn as nn
import torch.optim as optim
import torchvision
import torchvision.transforms as transforms
import lightning as L

from lightning.pytorch import Trainer
from lightning.pytorch.callbacks import ModelCheckpoint, LearningRateMonitor
from lightning.pytorch import loggers as l_loggers
from torch.utils.data import DataLoader
from datetime import datetime

# Define Lightning Module
class MinistResNet(L.LightningModule):
    def __init__(self, num_classes, lr, weight_decay, max_epochs=100):
        super().__init__()
        self.save_hyperparameters()
        self.model = torchvision.models.resnet18(pretrained=False)
        self.model.conv1 = nn.Conv2d(1, 64, kernel_size=7, stride=2, padding=3, bias=False)
        self.model.fc = nn.Linear(self.model.fc.in_features, num_classes)

    def forward(self, x):
        return self.model(x)

    def configure_optimizers(self):
        optimizer = optim.AdamW(self.parameters(), lr=self.hparams.lr, weight_decay=self.hparams.weight_decay)
        lr_scheduler = optim.lr_scheduler.MultiStepLR(
            optimizer, milestones=[int(self.hparams.max_epochs * 0.7), int(self.hparams.max_epochs * 0.9)], gamma=0.1
        )
        return [optimizer], [lr_scheduler]

    def _calculate_loss(self, batch, mode="train"):
        imgs, labels = batch
        preds = self.model(imgs)
        loss = nn.functional.cross_entropy(preds, labels)
        acc = (preds.argmax(dim=-1) == labels).float().mean()

        self.log(mode + "_loss", loss)
        self.log(mode + "_acc", acc)
        return loss

    def training_step(self, batch, batch_idx):
        return self._calculate_loss(batch, mode="train")

    def validation_step(self, batch, batch_idx):
        self._calculate_loss(batch, mode="val")

    def test_step(self, batch, batch_idx):
        self._calculate_loss(batch, mode="test")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Train ResNet on MNIST")
    parser.add_argument("--data_dir", type=str, required=True, help="Directory for the dataset")
    parser.add_argument("--model_dir", type=str, required=True, help="Directory to save the model")
    parser.add_argument("--log_dir", type=str, required=True, help="Directory to save logs")
    parser.add_argument("--version", type=str, default="1", help="Model version")
    args = parser.parse_args()

    # Read parameters from environment variables
    batch_size = int(os.getenv('BATCH_SIZE', 64))
    num_workers = int(os.getenv('NUM_WORKERS', 4))
    max_epochs = int(os.getenv('MAX_EPOCHS', 10))
    lr = float(os.getenv('LEARNING_RATE', 0.001))
    weight_decay = float(os.getenv('WEIGHT_DECAY', 0.0001))
    accelerator = os.getenv('ACCELERATOR', 'auto')
    strategy = os.getenv('DISTRIBUTED_BACKEND', 'ddp')  # Default to 'ddp' if not specified

    # Data preparation
    transform = transforms.Compose([
        transforms.Resize((224, 224)),
        transforms.ToTensor(),
        transforms.Normalize((0.1307,), (0.3081,))
    ])

    trainset = torchvision.datasets.MNIST(root=args.data_dir, train=True, download=True, transform=transform)
    testset = torchvision.datasets.MNIST(root=args.data_dir, train=False, download=True, transform=transform)
    trainloader = DataLoader(trainset, batch_size=batch_size, shuffle=True, num_workers=num_workers, pin_memory=True)
    testloader = DataLoader(testset, batch_size=batch_size, shuffle=False, num_workers=num_workers, pin_memory=True)

    # Initialize logger
    tb_logger = l_loggers.TensorBoardLogger(save_dir=args.log_dir)

    # Model version directory
    model_version_dir = os.path.join(args.model_dir, "mnist", args.version)
    os.makedirs(model_version_dir, exist_ok=True)

    # Training
    model = MinistResNet(num_classes=10, lr=lr, weight_decay=weight_decay, max_epochs=max_epochs)
    checkpoint_callback = ModelCheckpoint(
        dirpath=model_version_dir,
        filename="resnet18_mnist_{epoch:02d}_{val_acc:.2f}",
        save_weights_only=True,
        mode="max",
        monitor="val_acc"
    )
    lr_monitor = LearningRateMonitor(logging_interval='epoch')

    trainer = Trainer(
        max_epochs=max_epochs,
        accelerator=accelerator,
        logger=tb_logger,
        strategy=strategy if strategy != 'none' else None,  # Use None if strategy is 'none'
        callbacks=[checkpoint_callback, lr_monitor]
    )

    trainer.fit(model, train_dataloaders=trainloader, val_dataloaders=testloader)

    # Save model as TorchScript
    model_scripted = model.to_torchscript()
    #model_version_dir = os.path.join(args.model_dir, "mnist", args.version)
    #os.makedirs(model_version_dir, exist_ok=True)
    torch.jit.save(model_scripted, os.path.join(model_version_dir, "model.pt"))

    # Save model checkpoint
    current_time = datetime.now().strftime("%Y%m%d_%H%M")
    checkpoint_filename = f'resnet18_mnist_{current_time}.ckpt'
    # trainer.save_checkpoint(os.path.join(args.model_dir, checkpoint_filename))
    trainer.save_checkpoint(os.path.join(model_version_dir, checkpoint_filename))

    # Create config.pbtxt
    config = """
name: "mnist"
platform: "pytorch_libtorch"
max_batch_size: 128
input [
  {
    name: "input"
    data_type: TYPE_FP32
    format: FORMAT_NCHW
    dims: [ 1, 224, 224 ]
  }
]
output [
  {
    name: "output"
    data_type: TYPE_FP32
    dims: [ 10 ]
  }
]
"""
    with open(os.path.join(args.model_dir, "mnist", "config.pbtxt"), "w") as f:
      f.write(config)

    # Save model
    current_time = datetime.now().strftime("%Y%m%d_%H%M")
    model_filename = f'resnet18_mnist_{current_time}.ckpt'
    trainer.save_checkpoint(os.path.join(args.model_dir, model_filename))
